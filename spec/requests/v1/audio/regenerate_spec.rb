# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/regenerate_audio', type: :request do
  let_it_be(:user) { create(:user, :confirmed, :researcher) }

  let(:headers) { user.create_new_auth_token }
  let(:google_tts_voice) { create(:google_tts_voice) }
  let(:session) { create(:session, google_tts_voice: google_tts_voice) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_single, :narrator_block_one, question_group: question_group) }
  let(:block_text) { question.narrator['blocks'][0]['text'][0] }
  let(:audio) do
    unified_text = block_text.tr(',!.', '').strip.downcase
    Audio.find_by!(sha256: Digest::SHA256.hexdigest("#{unified_text}_#{google_tts_voice.language_code}_#{google_tts_voice.voice_type}"))
  end
  let(:voice_params) { { session_id: session.id } }
  let(:params) do
    {
      audio: {
        question_id: question.id,
        block_index: 0,
        audio_index: 0
      }.merge(voice_params)
    }
  end
  let(:request) { post v1_regenerate_audio_path, params: params, headers: headers, as: :json }

  def block_audio_url
    question.reload.narrator['blocks'][0]['audio_urls'][0]
  end

  context 'when user is not authenticated' do
    let(:headers) { {} }

    it_behaves_like 'unauthorized user'
  end

  context 'when audio param is missing' do
    # form-encoded on purpose: JSON bodies are wrapped under `audio` by ParamsWrapper
    let(:request) { post v1_regenerate_audio_path, params: { question_id: question.id }, headers: headers }

    it 'returns bad request' do
      request
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'when JSON body is sent without the audio root key' do
    let(:params) { { question_id: question.id, block_index: 0, audio_index: 0, session_id: session.id } }
    let!(:original_url) { block_audio_url }

    it 'wraps the params under audio and regenerates the block audio' do
      request
      expect(response).to have_http_status(:ok)
      expect(block_audio_url).not_to eq(original_url)
    end
  end

  context 'when block audio url points to the current audio file' do
    let!(:original_url) { block_audio_url }

    it 'returns ok' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'precondition: narrator block uses the audio generated with the session voice' do
      expect(original_url).to eq(audio.url)
    end

    it 'regenerates the audio file and swaps the url in the narrator block' do
      expect { request }.to change { audio.reload.url }
      expect(block_audio_url).not_to eq(original_url)
      expect(block_audio_url).to eq(audio.reload.url)
    end

    it 'does not create a new audio record' do
      expect { request }.not_to change(Audio, :count)
    end
  end

  context 'when block audio url is outdated' do
    let(:stale_url) { '/rails/active_storage/blobs/redirect/stale/old.mp3' }

    before do
      question.narrator['blocks'][0]['audio_urls'][0] = stale_url
      question.update_column(:narrator, question.narrator)
    end

    it 'does not regenerate the audio and swaps the block url to the current audio url' do
      current_url = audio.url
      expect { request }.not_to(change { audio.reload.url })
      expect(response).to have_http_status(:ok)
      expect(block_audio_url).to eq(current_url)
    end
  end

  context 'when current user has no access to the question' do
    let!(:original_url) { block_audio_url }

    before { request }

    context 'when user is a researcher who neither owns nor collaborates on the intervention' do
      let(:user) { create(:user, :confirmed, :researcher) }

      it 'returns forbidden' do
        pending 'BUG: AudioController#regenerate has no authorization check and lets unrelated researchers regenerate audio'
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not change the narrator of the question' do
        pending 'BUG: AudioController#regenerate has no authorization check and lets unrelated researchers overwrite the narrator'
        expect(block_audio_url).to eq(original_url)
      end
    end

    context 'when user is a participant without a user session of the session' do
      let(:user) { create(:user, :confirmed, :participant) }

      it 'returns forbidden' do
        pending 'BUG: AudioController#regenerate has no authorization check and lets unrelated participants regenerate audio'
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not change the narrator of the question' do
        pending 'BUG: AudioController#regenerate has no authorization check and lets unrelated participants overwrite the narrator'
        expect(block_audio_url).to eq(original_url)
      end
    end
  end

  describe 'voice resolution' do
    let!(:original_url) { block_audio_url }

    shared_examples 'regenerates audio with the resolved voice' do
      it 'passes the resolved voice to the service and regenerates the block audio' do
        allow(V1::Audio::Regenerate).to receive(:call).and_call_original
        request
        expect(response).to have_http_status(:ok)
        expect(V1::Audio::Regenerate).to have_received(:call)
          .with(anything, google_tts_voice.language_code, google_tts_voice.voice_type)
        expect(block_audio_url).not_to eq(original_url)
        expect(block_audio_url).to eq(audio.reload.url)
      end
    end

    context 'via session_id' do
      let(:voice_params) { { session_id: session.id } }

      it_behaves_like 'regenerates audio with the resolved voice'
    end

    context 'via user_session_id' do
      let(:user_session) { create(:user_session, session: session) }
      let(:voice_params) { { user_session_id: user_session.id } }

      it_behaves_like 'regenerates audio with the resolved voice'
    end

    context 'via google_tts_voice_id' do
      let(:voice_params) { { google_tts_voice_id: google_tts_voice.id } }

      it_behaves_like 'regenerates audio with the resolved voice'
    end

    context 'when user_session_id and session_id are both given' do
      let(:user_session) { create(:user_session, session: session) }
      let(:other_session) { create(:session, google_tts_voice: create(:google_tts_voice, voice_type: 'pl-PL-Standard-A', language_code: 'pl-PL')) }
      let(:voice_params) { { user_session_id: user_session.id, session_id: other_session.id } }

      it_behaves_like 'regenerates audio with the resolved voice'
    end
  end
end
