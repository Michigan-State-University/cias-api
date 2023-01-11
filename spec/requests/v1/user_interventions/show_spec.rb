# frozen_string_literal: true

RSpec.describe 'GET /v1/user_interventions/:id', type: :request do
  let!(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:flexible_order_intervention, user: user, shared_to: 'registered') }
  let!(:sessions) { create_list(:session, 3, intervention_id: intervention.id) }
  let!(:user_intervention) { create(:user_intervention, intervention_id: intervention.id, user: user) }

  let(:request) { get v1_user_intervention_path(user_intervention.id), headers: user.create_new_auth_token }

  context 'correct user intervention' do
    before { request }

    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct user intervention' do
      expect(json_response['data']['id']).to eq(user_intervention.id)
    end

    it 'returns correct amount of sessions' do
      expect(json_response['data']['attributes']['sessions_in_intervention']).to eq(sessions.size)
    end

    it 'returns correct intervention name' do
      expect(json_response['data']['attributes']['intervention']['name']).to eq intervention.name
    end

    it 'returns correct intervention type' do
      expect(json_response['data']['attributes']['intervention']['type']).to eq intervention.type
    end
  end
end
