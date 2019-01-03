require 'rails_helper'

describe ReviewablesController do

  context "anonymous" do
    it "denies listing" do
      get "/review.json"
      expect(response.code).to eq("403")
    end

    it "denies performing" do
      put "/review/123/perform/approve.json"
      expect(response.code).to eq("403")
    end
  end

  context "when logged in" do
    let(:moderator) { Fabricate(:moderator) }

    before do
      sign_in(moderator)
    end

    context "#index" do
      it "returns empty JSON when nothing to review" do
        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to eq([])
      end

      it "returns JSON with reviewable content" do
        reviewable = Fabricate(:reviewable)

        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewables']).to be_present

        json_review = json['reviewables'][0]
        expect(json_review['id']).to eq(reviewable.id)
        expect(json_review['status']).to eq(Reviewable.statuses[:pending])
        expect(json_review['type']).to eq('ReviewableUser')
        expect(json_review['payload']['list']).to match_array([1, 2, 3])
        expect(json_review['payload']['name']).to eq('bandersnatch')
      end

      it "will use the ReviewableUser serializer for its fields" do
        user = Fabricate(:user)
        reviewable = Fabricate(:reviewable, target_id: user.id)

        get "/review.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)

        json_review = json['reviewables'][0]
        expect(json_review['id']).to eq(reviewable.id)
        expect(json_review['user_id']).to eq(user.id)
        expect(json_review['username']).to eq(user.username)
        expect(json_review['email']).to eq(user.email)
        expect(json_review['name']).to eq(user.name)
      end
    end

    context "#perform" do
      let(:reviewable) { Fabricate(:reviewable) }

      it "returns 404 when the reviewable does not exist" do
        put "/review/12345/perform/approve.json"
        expect(response.code).to eq("404")
      end

      it "validates the presenece of an action" do
        put "/review/#{reviewable.id}/perform/nope.json"
        expect(response.code).to eq("403")
      end

      it "ensures the user can see the reviewable" do
        reviewable.update_column(:reviewable_by_moderator, false)
        put "/review/#{reviewable.id}/perform/approve.json"
        expect(response.code).to eq("404")
      end

      it "suceeds for a valid action" do
        put "/review/#{reviewable.id}/perform/approve.json"
        expect(response.code).to eq("200")
        json = ::JSON.parse(response.body)
        expect(json['reviewable_perform_result']['success']).to eq(true)
        expect(json['reviewable_perform_result']['transition_to']).to eq('approved')
        expect(json['reviewable_perform_result']['transition_to_id']).to eq(Reviewable.statuses[:approved])
      end
    end

  end

end
