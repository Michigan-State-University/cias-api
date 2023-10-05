# frozen_string_literal: true

# frozen_string_require: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_sessions', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, :multiple_times, intervention: intervention) }
  let(:health_clinic_id) { nil }
  let(:user_id) { user.id }
  let(:session_id) { session.id }
  let(:intervention_id) { intervention.id }
  let(:params) { { session_id: session_id, intervention: intervention_id } }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_user_sessions_path, headers: headers, params: params }

  context 'without tokens' do
    before { get v1_user_sessions_path, params: params }

    it 'return correct status' do
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when user intervention does\'t exits' do
    before do
      request
    end

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end

    it 'return correct error message' do
      expect(json_response['message']).to eql("Couldn't find UserIntervention")
    end
  end

  context 'when user session does\'t exits' do
    before do
      create(:user_intervention) { create(:user_intervention, intervention: intervention, user: user) }
      request
    end

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end

    it 'return correct error message' do
      expect(json_response['message']).to include("Couldn't find UserSession with")
    end
  end

  context 'when user session exists' do
    let(:user_session) do
      create(:user_session, user_intervention: create(:user_intervention, intervention: intervention, user: user), user: user, session: session)
    end

    before do
      user_session
      request
    end

    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct error message' do
      expect(json_response['data']['id']).to eq user_session.id
    end

    it 'has the "started" flag set to false' do
      expect(json_response['data']['attributes']['started']).to be false
    end

    it 'user session has the "started" flag set to true' do
      expect(user_session.reload.started).to be true
    end

    it 'user intervention has correct status' do
      expect(user_session.user_intervention.reload.status).to eq('in_progress')
    end
  end
end
