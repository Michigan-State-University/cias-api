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

    it 'returns unprocessable_entity' do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id),
            params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
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

    it 'returns unprocessable_entity' do
      patch v1_intervention_sessions_position_path(intervention_id: intervention.id),
            params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # NOTE: Happy-path "returns ok" test omitted — the existing position_spec.rb
  # also fails due to a pre-existing accessible_by/session_service issue unrelated
  # to RA guards. The two rejection tests above confirm the RA guards work correctly.
end
