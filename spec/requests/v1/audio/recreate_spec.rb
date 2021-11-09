# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/recreate_audio', type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:request) { post v1_recreate_audio_path, headers: user.create_new_auth_token }

  it 'when user isn\'t an admin' do
    request
    expect(response).to have_http_status(:forbidden)
  end

  context 'when it is admin' do
    let(:user) { create(:user, :confirmed, :admin) }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:ok)
    end
  end
end
