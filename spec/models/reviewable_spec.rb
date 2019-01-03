require 'rails_helper'

RSpec.describe Reviewable, type: :model do

  context ".create" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }

    let(:reviewable) { Fabricate.build(:reviewable, created_by: admin) }

    it "can create a reviewable object" do
      expect(reviewable).to be_present
      expect(reviewable.pending?).to eq(true)
      expect(reviewable.created_by).to eq(admin)

      expect(reviewable.payload).to be_present
      expect(reviewable.payload['name']).to eq('bandersnatch')
      expect(reviewable.payload['list']).to eq([1, 2, 3])
    end

    it "can add a target" do
      reviewable.target = user
      reviewable.save!

      expect(reviewable.target_type).to eq('User')
      expect(reviewable.target_id).to eq(user.id)
      expect(reviewable.target).to eq(user)
    end
  end

  context ".list_for" do
    it "returns an empty list for nil user" do
      expect(Reviewable.list_for(nil)).to eq([])
    end

    context "with a pending item" do
      let(:post) { Fabricate(:post) }
      let(:user) { Fabricate(:user) }

      let(:reviewable) { Fabricate(:reviewable, target: post) }

      it "works with the reviewable by moderator flag" do
        reviewable.reviewable_by_moderator = true
        reviewable.save!

        expect(Reviewable.list_for(user, status: :pending)).to be_empty
        user.update_column(:moderator, true)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])

        # Admins can review everything
        user.update_columns(moderator: false, admin: true)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])
      end

      it "works with the reviewable by group" do
        group = Fabricate(:group)
        reviewable.reviewable_by_group_id = group.id
        reviewable.save!

        expect(Reviewable.list_for(user, status: :pending)).to be_empty
        gu = GroupUser.create!(group_id: group.id, user_id: user.id)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])

        # Admins can review everything
        gu.destroy
        user.update_columns(moderator: false, admin: true)
        expect(Reviewable.list_for(user, status: :pending)).to eq([reviewable])
      end
    end
  end

  context "reviewable user" do
    let(:moderator) { Fabricate(:moderator) }
    let(:reviewable) { Fabricate(:reviewable) }
    context "actions_for" do
      it "returns approve/disapprove in the pending state" do
        actions = reviewable.actions_for(Guardian.new(moderator))
        expect(actions.has?(:approve)).to eq(true)
        expect(actions.has?(:reject)).to eq(true)
      end

      it "doesn't return anything in the approved state" do
        reviewable.status = Reviewable.statuses[:approved]
        actions = reviewable.actions_for(Guardian.new(moderator))
        expect(actions.has?(:approve)).to eq(false)
        expect(actions.has?(:reject)).to eq(false)
      end
    end

    context "perform" do
      it "allows us to approve a user" do
        result = reviewable.perform(moderator, :approve)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.approved?).to eq(true)
        expect(reviewable.target.approved?).to eq(true)
        expect(reviewable.target.approved_by_id).to eq(moderator.id)
        expect(reviewable.target.approved_at).to be_present
      end

      it "allows us to reject a user" do
        result = reviewable.perform(moderator, :reject)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
      end
    end
  end

end
