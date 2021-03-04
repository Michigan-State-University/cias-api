# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/position', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let(:session_1) { create(:session, position: 4, intervention: intervention) }
  let(:session_2) { create(:session, position: 5, intervention: intervention) }
  let(:session_3) { create(:session, position: 6, intervention: intervention) }
  let(:params) do
    {
      session: {
        position: [
          {
            id: session_1.id,
            position: 11
          },
          {
            id: session_2.id,
            position: 22
          },
          {
            id: session_3.id,
            position: 33
          }
        ]
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'proper order' do
        positions = json_response['sessions'].map { |session| session['position'] }
        expect(positions).to eq [11, 22, 33]
      end
    end
  end
end
