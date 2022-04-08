# frozen_string_literal: true

RSpec.describe 'POST /v1/interventions/:id/translate', type: :request do
  let(:path) { translate_v1_intervention_path(id: intervention.id) }
  let(:request) do
    post path, params: params, headers: headers
  end

  let_it_be(:dest_language) { GoogleLanguage.first }
  let_it_be(:dest_tts_voice) { GoogleTtsVoice.first }

  context 'translate intervention' do
    %i[admin researcher team_admin e_intervention_admin].each do |role|
      context "when user role is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }
        let(:session) { create(:session, name: 'Test session') }
        let(:intervention) { create(:intervention, name: 'Test intervention', user: user, sessions: [session]) }

        before { request }

        context 'correct intervention translation params' do
          describe 'tts voice id not null' do
            let(:params) do
              {
                dest_language_id: dest_language.id,
                destination_google_tts_voice_id: dest_tts_voice.id
              }
            end

            it 'properly translate intervention' do
              expect(response).to have_http_status(:created)
            end

            it 'returns proper data' do
              expect(json_response['data']['attributes']).to include({ 'google_language_id' => dest_language.id })
            end
          end

          describe 'tts voice id is null' do
            let(:params) do
              {
                dest_language_id: dest_language.id,
                destination_google_tts_voice_id: nil
              }
            end

            it 'properly translate intervention when tts voice id is nil' do
              expect(response).to have_http_status(:created)
            end

            it 'returns proper data' do
              expect(json_response['data']['attributes']).to include({ 'google_language_id' => dest_language.id })
            end
          end

          describe 'missing TTS language id' do
            let(:params) do
              {
                dest_language_id: dest_language.id
              }
            end

            it 'succeed in translation because tts language id is optional' do
              expect(response).to have_http_status(:created)
            end

            it 'returns proper data' do
              expect(json_response['data']['attributes']).to include({ 'google_language_id' => dest_language.id })
            end
          end
        end

        context 'missing dest language id' do
          let(:params) do
            {
              destination_google_tts_voice_id: dest_tts_voice.id
            }
          end

          it 'fail because of missing language id' do
            expect(response).to have_http_status(:bad_request)
          end
        end

        context 'no intervention found' do
          let(:params) do
            {
              dest_language_id: 20
            }
          end
          let(:request) do
            post translate_v1_intervention_path(id: '12345678'), params: params, headers: headers
          end

          it 'returns 404 (Not Found)' do
            expect(response).to have_http_status(:not_found)
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
        dest_language_id: dest_language.id,
        destination_google_tts_voice_id: dest_tts_voice.id
      }
    end

    it 'returns response code "Forbidden"' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end
