# frozen_string_literal: true

RSpec.describe 'POST /v1/live_chat/navigators/invitations', type: :request do
  let(:admin) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, user: admin) }

  let(:emails) do
    (5..10).map { |i| "email_#{i}@navigator.org" }
  end

  let(:request) do
    post v1_live_chat_navigators_invitations_path, headers: admin.create_new_auth_token, params: params
  end

  context 'Correctly invites emails' do
    let(:params) do
      {
        navigator_invitation: {
          emails: emails,
          intervention_id: intervention.id
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
