# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/users/confirm_logging_code', type: :request do
  let!(:user) { create(:user) }
  let(:code) { "verification_code_#{user.uid}" }
  let(:params) { { verification_code: code, email: user.email } }
  let(:request) { patch v1_confirm_logging_code_path, params: params }

  context 'when exists user with code and code is valid' do
    it 'return ok status and verification code' do
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['verification_code']).to eq "verification_code_#{user.uid}"
    end
  end

  context 'when exists user with code and code was expired' do
    let!(:user) { create(:user) }

    it 'return 408 status' do
      user.user_verification_codes.last.update!(created_at: Time.current - 2.hours)
      request
      expect(response).to have_http_status(:request_timeout)
    end
  end

  context 'when user with the code does not exist' do
    let!(:user) { create(:user) }
    let(:code) { 'invalid_code' }


    it 'return 404 status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
