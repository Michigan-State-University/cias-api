# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/phonetic_preview', type: :request do
  let(:user) { create(:user, :confirmed) }

  let(:params) do
    {
      audio: {
        text: 'text'
      }
    }
  end

  before do
    post v1_phonetic_preview_path, params: params, headers: user.create_new_auth_token
  end

  context 'phonetic preview' do
    context 'audio does not exist in DB' do
      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns url' do
        expect(json_response['url']).to include('.mp3')
      end
    end

    context 'audio exist in DB' do
      let(:sha256) { Digest::SHA256.hexdigest('text') }
      let(:audio) { create(:audio, sha256: sha256) }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns url' do
        expect(json_response['url']).to include('.mp3')
      end
    end
  end
end
