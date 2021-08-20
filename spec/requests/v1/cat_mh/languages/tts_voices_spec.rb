# frozen_string_literal: true

RSpec.describe 'GET /v1/cat_mh/languages/:language_id/voices', type: :request do
  let_it_be(:user) { create(:user, :confirmed, :admin) }
  let_it_be(:headers) { user.create_new_auth_token }
  let_it_be(:voices) { GoogleTtsVoice.all }
  let_it_be(:cat_mh_language) { CatMhLanguage.create!(language_id: 1, name: 'English', google_tts_voices: voices) }

  context 'authorized user' do
    let(:request) { get v1_cat_mh_language_voices_path(cat_mh_language.id), headers: headers }

    before { request }

    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct amount of tts voices' do
      expect(json_response['data'].size).to eq voices.size
    end

    it 'returns correct TTS voices' do
      expect(json_response['data'].map { |h| h['id'].to_i }).to match_array(voices.pluck(:id))
    end
  end

  context 'unauthorized user' do
    %i[researcher participant].each do |role|
      describe "when user has role #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }
        let(:request) { get v1_cat_mh_language_voices_path(cat_mh_language.id), headers: headers }

        it 'returns correct HTTP status code (Forbidden)' do
          request
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
