# frozen_string_literal: true

RSpec.describe 'POST /v1/interventions/:id/translate', type: :request do
  let(:path) { translate_v1_intervention_path(id: intervention.id) }
  let(:request) do
    post path, params: params, headers: headers
  end

  let_it_be(:dest_language) { create(:google_language) }
  let_it_be(:dest_tts_language) { create(:google_tts_language) }

  context 'translate intervention' do
    %i[admin researcher team_admin e_intervention_admin].each do |role|
      context "when user role is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }
        let(:intervention) { create(:intervention, name: 'Test intervention', user: user) }

        context 'correct intervention translation params' do
          describe 'tts language id not null' do
            let(:params) do
              {
                id: intervention.id,
                dest_language_id: dest_language.id,
                dest_tts_language_id: dest_tts_language.id
              }
            end

            it 'properly translate intervention' do
              request
              expect(response).to have_http_status(:created)
            end
          end

          describe 'tts language id is null' do
            let(:params) do
              {
                id: intervention.id,
                dest_language_id: dest_language.id,
                dest_tts_language_id: nil
              }
            end

            it 'properly translate intervention when tts language id is nil' do
              request
              expect(response).to have_http_status(:created)
            end
          end

          describe 'missing TTS language id' do
            let(:params) do
              {
                id: intervention.id,
                dest_language_id: dest_language.id
              }
            end

            it 'succeed in translation because tts language id is optional' do
              request
              expect(response).to have_http_status(:created)
            end
          end
        end

        context 'missing dest language id' do
          let(:params) do
            {
              id: intervention.id,
              dest_tts_language_id: dest_tts_language.id
            }
          end

          it 'fail because of missing language id' do
            request
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end
  end

  context 'user not permitted to translate' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }
    let(:intervention) { create(:intervention, name: 'Test intervention', user: user) }

    let(:params) do
      {
        id: intervention.id,
        dest_language_id: dest_language.id,
        dest_tts_language_id: dest_tts_language.id
      }
    end

    it 'returns response code "Forbidden"' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end
