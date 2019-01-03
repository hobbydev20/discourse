require_dependency 'enum'
require_dependency 'reviewable_actions'

class Reviewable < ActiveRecord::Base
  validates_presence_of :type, :status, :created_by_id
  belongs_to :target, polymorphic: true
  belongs_to :created_by, class_name: 'User'

  class PerformResult
    include ActiveModel::Serialization

    attr_reader :status, :transition_to

    def initialize(status, transition_to: nil)
      @status, @transition_to = status, transition_to
    end

    def success?
      status == :success
    end

    def failed?
      !success
    end
  end

  def self.statuses
    @statuses ||= Enum.new(
      pending: 0,
      approved: 1,
      rejected: 2,
      ignored: 3,
      deleted: 4
    )
  end

  # Generate `pending?`, `rejected?` helper methods
  statuses.each do |name, id|
    define_method("#{name}?") { status == id }
  end

  def actions_for(guardian)
    ReviewableActions.new(self, guardian).tap { |a| build_actions(a, guardian) }
  end

  # subclasses implement "build_actions" to list the actions they're capable of
  def build_actions
  end

  # Delegates to a `perform_#{action_id}` method, which returns a `PerformResult` with
  # the result of the operation and whether the status of the reviewable changed.
  def perform(performed_by, action_id)
    Guardian.new(performed_by).ensure_can_review!(self, action_id)

    perform_method = "perform_#{action_id}".to_sym

    raise "Invalid reviewable action `#{action_id}` on #{self.class.name}" unless respond_to?(perform_method)

    result = nil
    Reviewable.transaction do
      result = send(perform_method, performed_by)

      if result.success? && result.transition_to
        self.status = Reviewable.statuses[result.transition_to]
        save!
      end
    end
    result
  end

  def self.viewable_by(user)
    return all if user.admin?

    where(
      '(reviewable_by_moderator AND :staff) OR (reviewable_by_group_id IN (:group_ids))',
      staff: user.staff?,
      group_ids: user.group_users.pluck(:group_id)
    )
  end

  def self.list_for(user, status: :pending)
    return [] if user.blank?
    viewable_by(user).where(status: statuses[status]).includes(:target)
  end

end
