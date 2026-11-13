# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Communication::Sms do
  subject { described_class.new(message.id) }

  let(:message) { create :message, :with_code }
  let(:client) { subject.client }
  let(:call) { subject.send_message }

  it 'raise an error for non exist message' do
    expect { described_class.new('zzz') }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'has correct message body' do
    expect(subject.sms.body).to eq message.body
  end

  it 'has correct phone number' do
    expect(subject.sms.phone).to eq message.phone
  end

  describe '#send_message' do
    it 'changes message status to "success" after correct sending' do
      allow(client.messages).to receive(:create)
      expect { call }.to change { message.reload.status }.from('new').to('success')
    end

    context 'after unexpected error' do
      before do
        allow(client.messages).to receive(:create).and_raise(StandardError, 'Just error')
      end

      it 'changes message status to "error"' do
        expect { call }.to change { message.reload.status }.from('new').to('error')
      end

      it 'returns specific error' do
        call
        expect(subject.errors).to eq ['SMS sending error: StandardError, Just error']
      end
    end
  end

  describe 'opt-out guard' do
    subject(:sms) { described_class.new(message.id) }

    let(:user) { create(:user, :confirmed, :participant) }
    let!(:phone) { create(:phone, :confirmed, user: user) }
    let(:message) { create(:message, phone: phone.full_number, body: 'CIAS_TDD_CANARY_BODY') }

    before { allow(sms.client.messages).to receive(:create) }

    context 'when the recipient has opted out' do
      before { SmsOptOut.create!(user: user, opted_out_at: Time.current) }

      it 'does not hand the message to the provider' do
        sms.send_message
        expect(sms.client.messages).not_to have_received(:create)
      end

      it 'records the reason instead of raising' do
        sms.send_message
        expect(sms.errors.join).to include('RecipientOptedOut')
      end

      context 'when the message bypasses the opt-out' do
        subject(:sms) { described_class.new(message.id, bypass_opt_out: true) }

        it 'hands the message to the provider' do
          sms.send_message
          expect(sms.client.messages).to have_received(:create)
        end

        it 'records no error' do
          sms.send_message
          expect(sms.errors).to be_empty
        end
      end
    end

    context 'when the recipient has not opted out' do
      it 'hands the message to the provider' do
        sms.send_message
        expect(sms.client.messages).to have_received(:create)
      end
    end

    context 'when the number belongs to no user' do
      let(:message) { create(:message, phone: '+12015550129', body: 'CIAS_TDD_CANARY_BODY') }

      it 'hands the message to the provider' do
        sms.send_message
        expect(sms.client.messages).to have_received(:create)
      end
    end

    context 'when an opted-out recipient has a number with a trunk prefix' do
      let!(:phone) do
        Phone.new(user: user, iso: 'GB', prefix: '+44', number: '7400123456').tap { |stored| stored.save!(validate: false) }
      end
      let(:message) { create(:message, phone: '+447400123456', body: 'CIAS_TDD_CANARY_BODY') }

      before do
        SmsOptOut.create!(user: user, opted_out_at: Time.current)
      end

      it 'does not hand the message to the provider' do
        sms.send_message
        expect(sms.client.messages).not_to have_received(:create)
      end
    end
  end

  describe 'provider configuration' do
    let(:message) { create(:message, :with_code, phone: '+12015550123', body: SmsCampaignTestHelpers::CANARY_BODY) }
    let(:twilio_messages_url) { %r{\Ahttps://api\.twilio\.com/.*Messages} }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('TWILIO_ACCOUNT_SID', nil).and_return('ACcanary00000000000000000000000000')
      allow(ENV).to receive(:fetch).with('TWILIO_AUTH_TOKEN', nil).and_return('canary-auth-token')
      allow(ENV).to receive(:fetch).with('TWILIO_FROM', nil).and_return('+12015550199')
    end

    describe 'provider client has explicit HTTP timeouts' do
      let(:http_client) { described_class.new(message.id).client.http_client }

      it 'passes an explicit http_client with a positive timeout' do
        expect(http_client).to be_a(Twilio::HTTP::Client)
        expect(http_client.timeout).to be_a(Numeric).and be_positive
      end

      it 'applies both the open and the read timeout to the connection it builds' do
        stub_request(:get, 'https://api.twilio.com/timeout-probe').to_return(status: 200, body: '{}')

        http_client.request('https://api.twilio.com', 443, 'GET', 'https://api.twilio.com/timeout-probe', {}, {}, {}, %w[user pass])

        options = http_client.connection.options
        expect(options.open_timeout).to be_a(Numeric).and be_positive
        expect(options.timeout).to be_a(Numeric).and be_positive
      end

      it 'uses the same configuration when the sender is built from a Message object' do
        expect(described_class.new(message).client.http_client.timeout).to be_positive
      end
    end

    describe 'international destinations reach the provider' do
      let(:message) { create(:message, phone: '+447400123456', body: 'CIAS_TDD_CANARY_BODY') }
      let!(:twilio_stub) do
        stub_request(:post, %r{\Ahttps://api\.twilio\.com/}).to_return(
          status: 201, body: { sid: 'SMCIASTDD0001', status: 'queued' }.to_json, headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'hands a GB number to the provider and records the success' do
        described_class.new(message.id).send_message
        expect(twilio_stub).to have_been_requested
        expect(message.reload.status).to eq('success')
      end

      it 'hands a DE number to the provider' do
        german = create(:message, phone: '+4915112345678', body: 'CIAS_TDD_CANARY_BODY')
        described_class.new(german.id).send_message
        expect(twilio_stub).to have_been_requested
      end
    end

    describe 'the constructor accepts a Message or an id' do
      it 'accepts a Message instance and exposes it' do
        expect(described_class.new(message).sms).to eq(message)
      end

      it 'does not query messages when it is given a Message instance' do
        message
        queries = recorded_queries(/FROM "messages"/) { described_class.new(message) }

        expect(queries).to be_empty
      end

      it 'still accepts an id and loads the message with one query' do
        message
        queries = recorded_queries(/FROM "messages"/) { described_class.new(message.id) }

        expect(queries.size).to eq(1)
      end

      it 'sends a message passed as an object and marks it successful' do
        sms = described_class.new(message)
        allow(sms.client.messages).to receive(:create)

        expect { sms.send_message }.to change { message.reload.status }.from('new').to('success')
      end

      it 'still raises RecordNotFound for an unknown id' do
        expect { described_class.new(0) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'initialises an empty errors list for a Message' do
        expect(described_class.new(message).errors).to eq([])
      end
    end

    describe 'provider error codes' do
      def rest_error(code, text)
        Twilio::REST::RestError.new(text, Twilio::Response.new(400, { 'code' => code, 'message' => text }.to_json))
      end

      def code_after(error)
        sms = described_class.new(message.id)
        allow(sms.client.messages).to receive(:create).and_raise(error)
        sms.send_message
        sms.provider_error_code
      end

      it 'reports the Twilio code for an unverified destination' do
        expect(code_after(rest_error(21_608, 'The number is unverified'))).to eq('TWILIO_21608')
      end

      it 'tells an authentication failure apart from an unverified destination' do
        expect(code_after(rest_error(20_003, 'Authenticate'))).to eq('TWILIO_20003')
      end

      it 'tells an invalid sender apart as well' do
        expect(code_after(rest_error(21_212, 'Invalid From number'))).to eq('TWILIO_21212')
      end

      it 'keeps the destination number out of the code' do
        error = rest_error(21_614, 'To number: +15551234560, is not a mobile number')

        expect(code_after(error)).not_to include('5551234560')
      end

      it 'falls back to the exception class for a non-provider failure' do
        expect(code_after(StandardError.new('boom'))).to eq('StandardError')
      end

      it 'keeps the job timeout signature the campaign job re-raises on' do
        expect(code_after(ApplicationJob::JobTimeoutError.new('execution expired')))
          .to eq('ApplicationJob::JobTimeoutError')
      end

      it 'reports no code when nothing failed' do
        sms = described_class.new(message.id)
        allow(sms.client.messages).to receive(:create)
        sms.send_message

        expect(sms.provider_error_code).to be_nil
      end
    end

    describe 'provider timeout (existing behaviour kept)' do
      it 'a provider timeout leaves the message in error, fills errors and never raises' do
        sms = described_class.new(message.id)
        allow(sms.client.messages).to receive(:create).and_raise(Twilio::REST::TwilioError, 'execution expired')

        expect { sms.send_message }.not_to raise_error
        expect(message.reload.status).to eq('error')
        expect(sms.errors).to eq(['SMS sending error: Twilio::REST::TwilioError, execution expired'])
      end
    end
  end
end
