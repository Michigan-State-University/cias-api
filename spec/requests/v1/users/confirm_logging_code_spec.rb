# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/users/confirm_logging_code', type: :request do
  let!(:user) { create(:user, verification_code: '123') }
  let(:params) { { verification_code: '123' } }
  let(:request) { patch v1_confirm_logging_code_path, params: params }

  before do
    request
  end

  context 'when exists user with code and code is valid' do
    it 'return ok status and verification code' do
      expect(response).to have_http_status(:ok)
      expect(json_response['verification_code']).to eq '123'
    end
  end

  context 'when exists user with code and code was expired' do
    let!(:user) { create(:user, verification_code: '123', verification_code_created_at: Time.current - 2.hours) }

    it 'return 408 status' do
      expect(response).to have_http_status(:request_timeout)
    end
  end

  context 'when user with the code does not exist' do
    let!(:user) { create(:user, verification_code: '111', verification_code_created_at: Time.current - 2.hours) }

    it 'return 404 status' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
