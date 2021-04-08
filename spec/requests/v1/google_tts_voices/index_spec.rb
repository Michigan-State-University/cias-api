# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/google_tts_languages/:google_tts_language_id/google_tts_voices', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:team_admin) { create(:user, :confirmed, :team_admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :confirmed, :guest) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let(:language) { create(:google_tts_language, :with_voices) }
  let(:first_voice) { language.google_tts_voices.first }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_google_tts_language_google_tts_voices_path(language.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_google_tts_language_google_tts_voices_path(language.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper collection size' do
        expect(json_response['data'].size).to eq(3)
      end

      it 'returns proper collection data' do
        expect(json_response['data'][0]).to include(
          {
            'id' => first_voice.id.to_s,
            'type' => 'google_tts_voice',
            'attributes' => {
              'google_tts_language_id' => language.id,
              'voice_label' => first_voice.voice_label,
              'voice_type' => first_voice.voice_type,
              'language_code' => first_voice.language_code
            }
          }
        )
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when user is team_admin' do
      let(:headers) { team_admin.create_new_auth_token }

      it_behaves_like 'permitted user'
    end

    context 'when user is researcher' do
      let(:headers) { researcher.create_new_auth_token }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    context 'when user is participant' do
      let(:headers) { participant.create_new_auth_token }

      it_behaves_like 'unpermitted user'
    end

    context 'when user is guest user' do
      let(:headers) { guest.create_new_auth_token }

      it_behaves_like 'unpermitted user'
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
