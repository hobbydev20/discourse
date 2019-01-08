require 'rails_helper'

RSpec.describe ReviewableUser, type: :model do

  describe '.approve' do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    it "enqueues a 'signup after approval' email if must_approve_users is true" do
      SiteSetting.must_approve_users = true
      Jobs.expects(:enqueue).with(
        :critical_user_email, has_entries(type: :signup_after_approval)
      )
      user.approve(admin)
    end

    it "doesn't enqueue a 'signup after approval' email if must_approve_users is false" do
      SiteSetting.must_approve_users = false
      Jobs.expects(:enqueue).never
      user.approve(admin)
    end

    it 'triggers a extensibility event' do
      SiteSetting.must_approve_users = true

      user && admin # bypass the user_created event
      event = DiscourseEvent.track_events {
        Reviewable.find_by(target: user).perform(admin, :approve)
      }.first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end

    context 'after approval' do
      before do
        SiteSetting.must_approve_users = true
      end

      it 'marks the user as approved' do
        Reviewable.find_by(target: user).perform(admin, :approve)
        user.reload
        expect(user).to be_approved
        expect(user.approved_by).to eq(admin)
        expect(user.approved_at).to be_present
      end

    end
  end

end
