require_dependency 'reviewable_action_serializer'

class ReviewableSerializer < ApplicationSerializer
  attributes(
    :id,
    :status,
    :type,
    :payload,
    :created_at
  )

  has_many :reviewable_actions, serializer: ReviewableActionSerializer

  # Let's always return a payload to avoid null pointer exceptions
  def payload
    object.payload || {}
  end

  def reviewable_actions
    object.actions_for(scope).to_a
  end

  # This is easier than creating an AMS method for each attribute
  def self.target_attributes(*attributes)
    attributes.each do |a|
      attribute(a)

      class_eval <<~GETTER
        def #{a}
          object.target.#{a}
        end
      GETTER
    end
  end

  def attributes
    data = super

    # Automatically add the target id as a "good name" for example a target_type of `User`
    # becomes `user_id`
    data["#{object.target_type.downcase}_id"] = object.target_id

    data
  end

end
