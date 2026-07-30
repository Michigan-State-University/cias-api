# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::Hfhs::Authentication do
  include WebMock::API

  WebMock.enable!

  subject { described_class.call }

  let(:endpoint) { 'https://hfhs.test/token' }

  before do
    # ENDPOINT is baked from ENV at class load; CI ships HFHS_TOKEN_URL as an empty
    # string (cp .env.template .env), so stub the constant rather than the env var.
    stub_const('Api::Hfhs::Authentication::ENDPOINT', endpoint)
    # keep SslOptions from touching the trust store in a unit test
    allow(Api::Hfhs::SslOptions).to receive(:call).and_return(verify: false)
  end

  context 'when the token endpoint returns 200' do
    before do
      stub_request(:post, endpoint).to_return(
        status: 200,
        body: { access_token: 'abc', token_type: 'Bearer', expires_in: 3600 }.to_json
      )
    end

    it 'returns the parsed token' do
      expect(subject).to include(access_token: 'abc', token_type: 'Bearer')
    end
  end

  context 'when the token endpoint returns non-200' do
    before { stub_request(:post, endpoint).to_return(status: 401, body: '') }

    it 'returns nil' do
      expect(subject).to be_nil
    end
  end

  context 'when the TLS handshake fails' do
    before { stub_request(:post, endpoint).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed')) }

    it 're-raises Faraday::SSLError' do
      expect { subject }.to raise_error(Faraday::SSLError)
    end

    it 'logs the TLS error and reports to Sentry' do
      allow(Rails.logger).to receive(:error)
      allow(Sentry).to receive(:capture_exception)
      expect { subject }.to raise_error(Faraday::SSLError)
      expect(Rails.logger).to have_received(:error).with(/TLS verification failed/)
      expect(Sentry).to have_received(:capture_exception)
    end
  end
end
