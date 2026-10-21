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

    it 'returns correct intervention status' do
      expect(json_response['data']['attributes']['intervention']['status']).to eq intervention.status
    end

    it 'returns correct health clinic id' do
      expect(json_response['data']['attributes']['health_clinic_id']).to eq health_clinic.id
    end
  end

  context 'user_intervention with multiple sessions' do
    let!(:user_session1) do
      create(:user_session, user_intervention: user_intervention, health_clinic: health_clinic, session: sessions.first,
                            created_at: 1.month.ago, finished_at: 3.weeks.ago)
    end
    let!(:user_session2) do
      create(:user_session, user_intervention: user_intervention, health_clinic: health_clinic, session: sessions.first)
    end
    let!(:user_session3) do
      create(:user_session, user_intervention: user_intervention, health_clinic: health_clinic, session: sessions.second)
    end

    before { request }

    it {
      expect(json_response['data']['attributes']['user_sessions']['data'].count).to eq(2)
    }

    it {
      expect(json_response['data']['attributes']['user_sessions']['data'].map { |us| us['attributes']['filled_out_count'] }).to include(0, 1)
    }
  end

  context 'when another participant asks for the user intervention' do
    let(:other_participant) { create(:user, :participant, :confirmed) }
    let(:request) { get v1_user_intervention_path(user_intervention.id), headers: other_participant.create_new_auth_token }

    before { request }

    it 'is not found' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the participant has started a session' do
    let!(:user) { create(:user, :participant, :confirmed) }
    let!(:intervention) { create(:intervention, :published, shared_to: 'anyone') }
    let!(:user_session) do
      create(:user_session, user: user, session: sessions.first, user_intervention: user_intervention, health_clinic_id: health_clinic.id,
                            last_answer_at: 1.hour.ago)
    end

    before { request }

    it 'returns last_answer_date as the last answer timestamp' do
      pending 'BUG: UserIntervention#last_answer_date returns the whole latest UserSession record instead of its last_answer_at (T-55)'
      expect(json_response['data']['attributes']['last_answer_date']).to eq(user_session.last_answer_at.as_json)
    end
  end

  context 'predefined participnat has access to session shared to invited' do
    let!(:intervention) { create(:flexible_order_intervention, user: user, status: 'published', shared_to: 'invited') }
    let!(:user) { create(:user, :predefined_participant, :confirmed) }

    before { request }

    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct blocked status' do
      expect(json_response['data']['attributes']['blocked']).to be(false)
    end
  end
end
