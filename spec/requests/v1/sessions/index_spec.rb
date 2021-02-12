# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/sessions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_intervention_sessions_path(intervention.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_intervention_sessions_path(intervention.id), headers: headers }

      it 'response contains proper uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_intervention_sessions_path(intervention.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_intervention_sessions_path(intervention.id), headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end
  end
end
