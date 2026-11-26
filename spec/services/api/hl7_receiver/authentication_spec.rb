# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::Hl7Receiver::Authentication do
  include WebMock::API

  WebMock.enable!

  subject { described_class.call }

  let(:endpoint) { 'https://hfhs.test/token' }

  include_context 'with environment variables', {
    'HL7_RECEIVER_TOKEN_URL' => 'https://hfhs.test/token',
    'HL7_RECEIVER_USERNAME' => 'cias-user',
    'HL7_RECEIVER_CLIENT_ID' => 'cias-client',
    'HL7_RECEIVER_CLIENT_SECRET' => 'client-secret',
    'HL7_RECEIVER_PASSWORD' => 'user-password'
  }

  # keep SslOptions from touching the trust store in a unit test
  before { allow(Api::Hl7Receiver::SslOptions).to receive(:call).and_return(verify: false) }

  context 'when the token endpoint returns 200' do
    let!(:token_request) do
      stub_request(:post, endpoint)
        .with(body: { grant_type: 'password', username: 'cias-user', client_id: 'cias-client',
                      client_secret: 'client-secret', password: 'user-password' })
        .to_return(status: 200, body: { access_token: 'abc', token_type: 'Bearer', expires_in: 3600 }.to_json)
    end

    it 'posts the password grant with the configured credentials and returns the parsed token' do
      expect(subject).to include(access_token: 'abc', token_type: 'Bearer')
      expect(token_request).to have_been_requested
    end
  end

  context 'when the token URL is not set' do
    include_context 'with environment variables', { 'HL7_RECEIVER_TOKEN_URL' => nil }

    before { allow(Sentry).to receive(:capture_message) }

    it 'raises naming the setting before any request' do
      expect { subject }.to raise_error(Ehr::Settings::MissingSettingError, 'HL7_RECEIVER_TOKEN_URL is not set')
      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it 'reports the missing setting to Sentry on this attempt' do
      expect { subject }.to raise_error(Ehr::Settings::MissingSettingError)
      expect(Sentry).to have_received(:capture_message)
        .with('[Ehr::Settings] HL7 send stopped, HL7_RECEIVER_TOKEN_URL is not set').once
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

    it 'logs the TLS error with the setting names and reports it to Sentry with the endpoint' do
      scope = instance_double(Sentry::Scope, set_context: nil)
      allow(Rails.logger).to receive(:error)
      allow(Sentry).to receive(:capture_exception).and_yield(scope)
      expect { subject }.to raise_error(Faraday::SSLError)
      expect(Rails.logger).to have_received(:error).with(
        a_string_including(
          "[HL7 receiver] TLS verification failed calling #{endpoint}",
          'Check HL7_RECEIVER_CA_CERT, or set HL7_RECEIVER_SSL_VERIFY=false to roll back.'
        )
      )
      expect(scope).to have_received(:set_context).with('hl7_receiver_request', { endpoint: endpoint })
    end
  end
end
