# frozen_string_literal: true

RSpec.describe 'POST /v1/interventions/:intervention_id/navigator_invitations', type: :request do
  let(:admin) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, user: admin) }

  let(:emails) do
    (5..10).map { |i| "email_#{i}@navigator.org" }
  end

  let(:request) do
    post v1_intervention_navigator_invitations_path(intervention.id), headers: admin.create_new_auth_token, params: params
  end

  context 'Correctly invites emails' do
    let(:params) do
      {
        navigator_invitation: {
          emails: emails
        }
      }
    end
    let!(:old_user_count) { User.count }
    let!(:invitations_old_count) { intervention.live_chat_navigator_invitations.count }

    it 'returns correct status code (OK)' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'correctly invites users to system' do
      request
      expect(User.count).to eq(old_user_count + emails.length + 1) # we add 1 because it also takes admin into consideration
    end

    it 'correctly invites users to intervention' do
      request
      expect(intervention.live_chat_navigator_invitations.reload.count).to eq(invitations_old_count + emails.length)
    end

    it 'returns correct amount of created invitations' do
      request
      expect(json_response['data'].length).to eq emails.length
    end
  end

  context 'Existed user cannot become a navigator' do
    let(:participant) { create(:user, :confirmed, :participant) }
    let(:params) do
      {
        navigator_invitation: {
          emails: [participant.email]
        }
      }
    end

    it 'returns correct status code (FORBIDDEN) and msg' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq 'User cannot become a navigator'
    end
  end

  context 'Incorrect params' do
    let(:params) do
      {}
    end

    before { request }

    it 'returns correct status code (Bad Request)' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'does not change invitation & users count' do
      expect { request }.not_to change(User, :count)
    end
  end
end
