# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /oauth/token', type: :request do
  let(:oauth_application) { Doorkeeper::Application.create!(name: 'test_app') }
  let(:headers) { { 'Content-Type': 'application/x-www-form-urlencoded' } }
  let(:params) { { grant_type: 'client_credentials', client_id: oauth_application.uid, client_secret: oauth_application.secret } }
  let(:request) { post oauth_token_path, params: params, headers: headers }

  before { request }

  it {
    expect(response).to have_http_status(:ok)
  }
end
