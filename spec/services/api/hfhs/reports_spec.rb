# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::Hfhs::Reports do
  include WebMock::API

  WebMock.enable!

  subject { described_class.call(user_session.id) }

  let(:endpoint) { 'https://hfhs.test/data' }
  let(:patient) { create(:user, :with_hfhs_patient_detail, :confirmed) }
  let(:user_session) { create(:user_session, user: patient) }

  before do
    # ENDPOINT is baked from ENV at class load; CI ships HFHS_URL empty, so stub it.
    stub_const('Api::Hfhs::Reports::ENDPOINT', endpoint)
    allow(Api::Hfhs::SslOptions).to receive(:call).and_return(verify: false)
    allow(Hl7::GeneratedReportMapper).to receive(:call).and_return('MSH|test')
  end

  context 'when there are no henry_ford_health reports' do
    it 'returns without authenticating or POSTing' do
      expect(Api::Hfhs::Authentication).not_to receive(:call)
      subject
    end
  end

  context 'with a henry_ford_health report' do
    let!(:report) { create(:generated_report, report_for: 'henry_ford_health', user_session: user_session) }

    context 'when no token is issued' do
      before { allow(Api::Hfhs::Authentication).to receive(:call).and_return(nil) }

      it 'warns about the skipped delivery and does not POST' do
        allow(Rails.logger).to receive(:warn)
        subject
        expect(Rails.logger).to have_received(:warn).with(/no token issued - skipping reports send/)
      end
    end

    context 'when a token is issued' do
      before do
        allow(Api::Hfhs::Authentication).to receive(:call).and_return(token_type: 'Bearer', access_token: 'abc')
      end

      it 'POSTs each report to the gateway' do
        stub = stub_request(:post, endpoint).to_return(status: 200, body: '')
        subject
        expect(stub).to have_been_requested
      end

      it 'reports the TLS error and re-raises on handshake failure' do
        stub_request(:post, endpoint).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))
        allow(Sentry).to receive(:capture_exception)
        expect { subject }.to raise_error(Faraday::SSLError)
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end
end
