# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::Hfhs::UserSession do
  include WebMock::API

  WebMock.enable!

  subject { described_class.call(user_session.id) }

  let(:endpoint) { 'https://hfhs.test/data' }
  let(:patient) { create(:user, :with_hfhs_patient_detail, :confirmed) }
  let(:user_session) { create(:user_session, user: patient) }

  before do
    # ENDPOINT is baked from ENV at class load; CI ships HFHS_URL empty, so stub it.
    stub_const('Api::Hfhs::UserSession::ENDPOINT', endpoint)
    allow(Api::Hfhs::SslOptions).to receive(:call).and_return(verify: false)
    allow(Hl7::UserSessionMapper).to receive(:call).and_return('MSH|test')
  end

  context 'when there are no Answer::HenryFord answers' do
    it 'returns without authenticating or POSTing' do
      expect(Api::Hfhs::Authentication).not_to receive(:call)
      subject
    end
  end

  context 'with a HenryFord answer' do
    let(:session) { create(:session) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_henry_ford, question_group: question_group) }
    let!(:answer) { create(:answer_henry_ford, user_session: user_session, question: question) }

    context 'when no token is issued' do
      before { allow(Api::Hfhs::Authentication).to receive(:call).and_return(nil) }

      it 'warns about the skipped delivery and does not POST' do
        allow(Rails.logger).to receive(:warn)
        subject
        expect(Rails.logger).to have_received(:warn).with(/no token issued - skipping answers send/)
      end
    end

    context 'when a token is issued' do
      before do
        allow(Api::Hfhs::Authentication).to receive(:call).and_return(token_type: 'Bearer', access_token: 'abc')
      end

      it 'POSTs the answers to the gateway' do
        stub = stub_request(:post, endpoint).to_return(status: 200, body: '')
        subject
        expect(stub).to have_been_requested
      end

      it 'warns and reports to Sentry when the gateway rejects the send' do
        stub_request(:post, endpoint).to_return(status: 500, body: '')
        allow(Rails.logger).to receive(:warn)
        allow(Sentry).to receive(:capture_message)
        subject
        expect(Rails.logger).to have_received(:warn).with(/-> 500 - delivery not accepted/)
        expect(Sentry).to have_received(:capture_message)
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
