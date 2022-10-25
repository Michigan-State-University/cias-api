# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/intervention/:id/navigators', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigators, user: user) }
  let(:navigator) { intervention.navigators.first }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_live_chat_intervention_navigators_path(id: intervention.id), headers: headers
  end

  before { request }

  context 'when user has access' do
    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data' do
      expect(json_response['data'].first).to include(
        'id' => navigator.id,
        'type' => 'navigator',
        'attributes' => include(
          'first_name' => navigator.first_name,
          'last_name' => navigator.last_name,
          'email' => navigator.email,
          'avatar_url' => nil
        )
      )
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
