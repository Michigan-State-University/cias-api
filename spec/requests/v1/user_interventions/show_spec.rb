# frozen_string_literal: true

RSpec.describe 'GET /v1/user_interventions/:id', type: :request do
  let!(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:flexible_order_intervention, user: user, status: 'published', shared_to: 'registered') }
  let!(:sessions) { create_list(:session, 3, intervention_id: intervention.id) }
  let!(:health_clinic) { create(:health_clinic) }
  let!(:user_intervention) { create(:user_intervention, intervention_id: intervention.id, user: user, health_clinic_id: health_clinic.id) }

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

    it 'returns correct health clinic id' do
      expect(json_response['data']['attributes']['health_clinic_id']).to eq health_clinic.id
    end
  end

  context 'user_intervention with multiple sessions' do
    let!(:user_session1) do
      create(:user_session, user_intervention: user_intervention, session: sessions.first, created_at: 1.month.ago, finished_at: 3.weeks.ago)
    end
    let!(:user_session2) { create(:user_session, user_intervention: user_intervention, session: sessions.first) }
    let!(:user_session3) { create(:user_session, user_intervention: user_intervention, session: sessions.second) }

    before { request }

    it {
      expect(json_response['data']['attributes']['user_sessions']['data'].count).to eq(2)
    }

    it {
      expect(json_response['data']['attributes']['user_sessions']['data'].map { |us| us['attributes']['filled_out_count'] }).to include(0, 1)
    }
  end
end
