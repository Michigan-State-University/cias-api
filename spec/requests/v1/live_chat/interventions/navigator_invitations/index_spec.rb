# frozen_string_literal: true

RSpec.describe 'GET /v1/interventions/:intervention_id/navigator_invitations', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_intervention_navigator_invitations_path(intervention_id: intervention.id), headers: headers
  end
  let!(:navigator_invitations) { create_list(:navigator_invitation, 4, intervention: intervention) }
  let!(:accepted_invitation) { create(:navigator_invitation, :confirmed, intervention: intervention) }

  before { request }

  context 'when user has access' do
    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data' do
      expect(json_response['data'].map { |invitation| invitation['attributes']['email'] }).to match_array(navigator_invitations.pluck(:email))
    end
  end

  context 'other researcher' do
    let(:other_researcher) { create(:user, :researcher, :confirmed) }
    let(:headers) { other_researcher.create_new_auth_token }

    it 'return correct status code and msg' do
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include("Couldn't find Intervention with 'id'=")
    end
  end
end
