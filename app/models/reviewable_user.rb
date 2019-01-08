require_dependency 'reviewable'

class ReviewableUser < Reviewable
  def self.create_for(user)
    create(
      created_by_id: Discourse.system_user.id,
      target: user
    )
  end

  def build_actions(actions, guardian, args)
    return unless pending?

    actions.add(:approve) if guardian.can_approve?(target) || args[:approved_by_invite]
    actions.add(:reject) if guardian.can_delete_user?(target)
  end

  def perform_approve(performed_by, args)
    ReviewableUser.setup_approval(target, performed_by)
    target.save!

    DiscourseEvent.trigger(:user_approved, target)

    if args[:send_email] && SiteSetting.must_approve_users?
      Jobs.enqueue(
        :critical_user_email,
        type: :signup_after_approval,
        user_id: target.id
      )
    end

    PerformResult.new(:success, transition_to: :approved)
  end

  def perform_reject(performed_by, args)
    destroyer = UserDestroyer.new(performed_by)
    destroyer.destroy(target)

    PerformResult.new(:success, transition_to: :rejected)
  rescue UserDestroyer::PostsExistError
    PerformResult.new(:failed)
  end

  # Update's the user's fields for approval but does not save. This
  # can be used when generating a new user that is approved on create
  def self.setup_approval(user, approved_by)
    user.approved = true
    user.approved_by ||= approved_by
    user.approved_at ||= Time.zone.now
  end
end
