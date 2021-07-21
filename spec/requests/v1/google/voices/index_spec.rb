# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/google/languages/:language_id/voices', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_google_language_voices_path(language1.id), headers: headers }

  let_it_be(:language1) { create(:google_language) }
  let_it_be(:language2) { create(:google_language, language_name: 'Polish', language_code: 'pl') }

  let_it_be(:google_tts_voice1) { create(:google_tts_voice, language_code: "#{language1.language_code}-1") }
  let_it_be(:google_tts_voice2) { create(:google_tts_voice, language_code: "#{language1.language_code}-2") }
  let_it_be(:google_tts_voice3) { create(:google_tts_voice, language_code: "#{language1.language_code}-3") }
  let_it_be(:google_tts_voice4) { create(:google_tts_voice, language_code: "#{language2.language_code}-1") }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_google_language_voices_path(language1.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'return proper collection size' do
        expect(json_response['data'].size).to be(3)
      end

      context 'correct data' do
        let(:request) { get v1_google_language_voices_path(language2.id), headers: headers }

        it 'return one element' do
          expect(json_response['data'].size).to be(1)
        end

        it 'return proper collection data' do
          expect(json_response['data']).to include(
            {
              'id' => google_tts_voice4.id.to_s,
              'type' => 'voice',
              'attributes' => include(
                'voice_label' => google_tts_voice4.voice_label,
                'voice_type' => google_tts_voice4.voice_type,
                'language_code' => google_tts_voice4.language_code
              )
            }
          )
        end
      end
    end

    %w[admin team_admin researcher].each do |role|
      context role.to_s do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'permitted user'
      end
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %w[guest participant].each do |role|
      context role.to_s do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
