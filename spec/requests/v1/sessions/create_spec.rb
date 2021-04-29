# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/sessions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:intervention) { create(:intervention) }
  let(:headers) { user.create_new_auth_token }
  let(:language) { create(:google_tts_language) }
  let(:first_voice) { create(:google_tts_voice, google_tts_language: language) }

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

  context 'one or multiple roles' do
    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }
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
            end
          end
        end

        context 'when first session have default voice settings' do
          let!(:session) { create(:session, intervention_id: intervention.id, google_tts_voice_id: first_voice.id) }

          it 'return good voice settings' do
            expect(Session.last.google_tts_voice).to eq(first_voice)
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
  end
end
