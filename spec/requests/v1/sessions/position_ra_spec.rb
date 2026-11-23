# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/position (RA guards)', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let!(:ra_session) { create(:ra_session, intervention: intervention) }
  let!(:classic_session1) { create(:session, position: 1, intervention: intervention) }
  let!(:classic_session2) { create(:session, position: 2, intervention: intervention) }
  let(:headers) { user.create_new_auth_token }

  context 'when attempting to reposition an RA session' do
    let(:params) do
      {
        session: {
          position: [
            { id: ra_session.id, position: 5 },
            { id: classic_session1.id, position: 1 },
            { id: classic_session2.id, position: 2 }
          ]
        }
      }
    end

    it 'returns unprocessable_content' do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id),
            params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'when attempting to assign position 0 to a non-RA session' do
    let(:params) do
      {
        session: {
          position: [
            { id: classic_session1.id, position: 0 },
            { id: classic_session2.id, position: 2 }
          ]
        }
      }
    end

    it 'returns unprocessable_content' do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id),
            params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context 'when the RA session id is sent in upper case' do
    let(:params) { { session: { position: [{ id: ra_session.id.upcase, position: 5 }, { id: classic_session1.id, position: 1 }] } } }

    it 'returns unprocessable_content and keeps the RA session at position 0' do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(ra_session.reload.position).to eq 0
    end
  end

  context 'when a position is not a whole number' do
    it 'returns the invalid positions error' do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id),
            params: { session: { position: [{ id: classic_session1.id, position: true }] } }.to_json,
            headers: headers.merge('Content-Type' => 'application/json')

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['message']).to eq I18n.t('exceptions.invalid_positions')
    end
  end
end
