# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/users/confirm_terms', type: :request do
  let!(:user) { create(:user) }
  let(:params) { { terms: true, email: user.email, password: user.password } }
  let(:request) { patch v1_confirm_terms_path, params: params }

  context 'when email is correct' do
    it 'return ok status' do
      request
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when email is not correct' do
    let(:params) { { terms: true, email: 'not_existing@email.com' } }

    it 'return not found status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
