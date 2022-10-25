# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/intervention/:id/navigator_setups', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_live_chat_intervention_navigator_setup_path(id: intervention.id), headers: headers
  end

  before { request }

  context 'correctly fetches setup data' do
    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data' do
      expect(json_response['data']['attributes']).to include(
        'notify_by' => 'email',
        'contact_email' => '',
        'no_navigator_available_message' => '',
        'is_navigator_notification_on' => true
      )
    end

    it 'have correct keys' do
      expect(json_response.keys).to contain_exactly('data', 'included')
      expect(json_response['data'].keys).to contain_exactly('id', 'type', 'attributes', 'relationships')
    end
  end

  context 'when user has no permission to intervention' do
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:headers) { researcher.create_new_auth_token }

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
