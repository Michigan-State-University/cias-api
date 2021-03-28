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
  let(:request) { patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_intervention_sessions_position_path(intervention_id: intervention.id), params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before { request }

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
