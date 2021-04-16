# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/sessions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:headers) { user.create_new_auth_token }
  let(:language) { create(:google_tts_language) }
  let(:first_voice) { create(:google_tts_voice, google_tts_language: language) }
  let!(:session) { create(:session, intervention_id: intervention.id, google_tts_voice_id: first_voice.id) }
  let(:params) do
    {
      session: {
        name: 'research_assistant test1',
        intervention_id: intervention.id,
        body: {
          data: [
            {
              payload: 1,
              target: '',
              variable: '1'
            }
          ]
        }
      }
    }
  end
  let(:request) { post v1_intervention_sessions_path(intervention_id: intervention.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_intervention_sessions_path(intervention_id: intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when params' do
    context 'valid' do
      before do
        allow_any_instance_of(Kernel).to receive(:rand).and_return(1234)
        request
      end

      it { expect(response).to have_http_status(:success) }

      context 'when variable is missing' do
        it 'adding default value for variable' do
          expect(Session.last.variable).to eq 's1234'
          expect(Session.last.google_tts_voice).to eq(first_voice)
        end
      end
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          post v1_intervention_sessions_path(intervention_id: intervention.id), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
