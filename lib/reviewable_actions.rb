class ReviewableActions
  attr_reader :actions

  # A lot of actions will be named the same thing: "Approve" and "Reject", for example.
  # We can set defaults here for those so we can have less configuration.
  def self.defaults
    @@default ||= {
      approve: {
        icon: 'far-thumbs-up',
        title: "reviewables.actions.approve.title"
      },
      reject: {
        icon: 'far-thumbs-down',
        title: "reviewables.actions.reject.title"
      }
    }
  end

  class Action
    include ActiveModel::Serialization

    attr_reader :id, :reviewable, :title, :icon

    def initialize(reviewable, id, args)
      @reviewable, @id = reviewable, id
      defaults = ReviewableActions.defaults[id] || {}
      @title = args[:title] || defaults[:title] || "reviewables.#{reviewable.type.underscore}.actions.#{id}.title"
      @icon = args[:icon] || defaults[:icon]
    end
  end

  def initialize(reviewable, guardian)
    @reviewable, @guardian = reviewable, guardian
    @actions = []
  end

  def add(id, args = nil)
    @actions << Action.new(@reviewable, id, args || {})
  end

  def has?(id)
    @actions.find { |a| a.id == id }.present?
  end

  def to_a
    @actions
  end

end
