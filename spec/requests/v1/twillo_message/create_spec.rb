# frozen_string_literal: true

require 'rails_helper'
require 'support/scheduled_sms_helpers'

RSpec.describe 'POST /v1/sms/replay', type: :request do
  context 'when valid params are passed' do
    before do
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(
        {
          status: 200
        }
      )
    end

    let(:params) do
      {
        body: 'EXAMPLE',
        from: '+48555777555',
        to: '+48555777888'
      }
    end
    let(:auth_token) { 'tdd_canary_twilio_auth_token' }
    let(:webhook_url) { 'http://www.example.com/v1/sms/replay' }
    let(:signature) { Twilio::Security::RequestValidator.new(auth_token).build_signature_for(webhook_url, params.stringify_keys) }
    let(:request) { post v1_sms_replay_path, params: params, headers: { 'X-Twilio-Signature' => signature } }

    around do |example|
      previous = ENV.fetch('TWILIO_AUTH_TOKEN', nil)
      ENV['TWILIO_AUTH_TOKEN'] = auth_token
      example.run
    ensure
      ENV['TWILIO_AUTH_TOKEN'] = previous
    end

    context 'basic functionality' do
      it 'receive and pass params to service' do
        expect(V1::Sms::Replay).to receive(:call).with(
          params[:from], params[:to], params[:body]
        )
        request
      end

      it 'correct type of response' do
        request
        expect(response.headers['Content-Type']).to eq('application/xml; charset=utf-8')
      end
    end

    context 'when Sms Session Code is provided' do
      let(:params) do
        {
          body: 'SMS_CODE_1',
          from: user.phone.full_number,
          to: '+48555777888'
        }
      end

      context 'when user session with sms code is NOT created' do
        let!(:intervention) { create(:intervention, :published) }
        let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
        let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention) }
        let!(:user) { create(:user, :with_phone) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

        it 'creates new user session' do
          expect { request }.to change(user.user_sessions, :count).by(1)
        end

        it 'schedules new user session job' do
          expect { request }.to have_enqueued_job(UserSessionJobs::ScheduleDailyMessagesJob)
        end
      end

      context 'when user session with sms code is already created' do
        let!(:intervention) { create(:intervention, :published) }
        let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
        let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention) }
        let(:user) { create(:user, :with_phone) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session) }

        it 'does not create new user session' do
          expect { request }.not_to change(user.user_sessions, :count)
        end

        context 'and there is pending question' do
          let!(:user) { create(:user, :with_phone) }
          let!(:intervention) { create(:intervention, :published) }
          let!(:question_group_initial) { build(:question_group_initial) }
          let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
          let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
          let!(:question_group) { create(:sms_question_group, session: session) }
          let!(:question) { create(:question_sms, question_group: question_group) }
          let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
          let!(:user_session) { create(:sms_user_session, user: user, session: session) }

          it 'does not create new answer' do
            expect { request }.not_to change(user_session.answers, :count)
          end
        end

        context 'and there are no pending questions' do
          let!(:user) { create(:user, :with_phone) }
          let!(:intervention) { create(:intervention, :published) }
          let!(:question_group_initial) { build(:question_group_initial) }
          let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
          let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
          let!(:question_group) { create(:sms_question_group, session: session) }
          let!(:question) { create(:question_sms, question_group: question_group) }
          let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
          let!(:user_session) { create(:sms_user_session, user: user, session: session) }
          let!(:answer) { create(:answer_sms, user_session: user_session, question: question) }

          it 'does not create any answer' do
            expect { request }.not_to change(user_session.answers, :count)
          end
        end
      end
    end

    context 'when answer is provided' do
      let(:params) do
        {
          body: '1',
          from: user.phone.full_number,
          to: '+48555777888'
        }
      end

      context 'when there is pending question' do
        let!(:user) { create(:user, :with_phone, pending_sms_answer: true) }
        let!(:intervention) { create(:intervention) }
        let!(:question_group_initial) { build(:question_group_initial) }
        let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
        let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
        let!(:question_group) { create(:sms_question_group, session: session) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session, current_question_id: question.id) }

        context 'when answer is in accepted values' do
          context 'when there are specific accepted values' do
            let!(:question) { create(:question_sms, question_group: question_group, accepted_answers: { predefined: %w[1 2] }) }

            it 'creates new answer' do
              expect { request }.to change(user_session.answers, :count).by(1)
            end
          end

          context 'when there is range of accepted values' do
            let!(:question) { create(:question_sms, question_group: question_group, accepted_answers: { range: { from: '1', to: '3' } }) }

            it 'creates new answer' do
              expect { request }.to change(user_session.answers, :count).by(1)
            end
          end
        end

        context 'when answer is NOT in accepted values' do
          let!(:question) { create(:question_sms, question_group: question_group, accepted_answers: { predefined: %w[3 4] }) }

          it 'does not create new answer' do
            expect { request }.not_to change(user_session.answers, :count)
          end
        end
      end

      context 'when there are no pending questions' do
        let!(:user) { create(:user, :with_phone) }
        let!(:intervention) { create(:intervention) }
        let!(:question_group_initial) { build(:question_group_initial) }
        let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
        let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
        let!(:question_group) { create(:sms_question_group, session: session) }
        let!(:question) { create(:question_sms, question_group: question_group) }
        let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session) }
        let!(:answer) { create(:answer_sms, user_session: user_session, question: question) }

        it 'does not create any answer' do
          expect { request }.not_to change(user_session.answers, :count)
        end
      end

      context 'when user session is not created' do
        let!(:intervention) { create(:intervention) }
        let!(:sms_code) { build(:sms_code, sms_code: 'SMS_CODE_1') }
        let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention) }
        let(:user) { create(:user, :with_phone) }

        it 'does not create any user session' do
          expect { request }.not_to change(user.user_sessions, :count)
        end
      end
    end
  end

  describe 'signed Twilio webhook' do
    include ActiveSupport::Testing::TimeHelpers
    include ScheduledSmsHelpers

    let(:auth_token) { 'tdd_canary_twilio_auth_token' }
    let(:webhook_url) { 'http://www.example.com/v1/sms/replay' }
    let!(:user) { create(:user, :confirmed, :participant) }
    let!(:phone) { create(:phone, :confirmed, user: user) }
    let(:from) { phone.full_number }
    let(:to) { '+12015550130' }
    let(:body) { 'STOP' }
    let(:message_sid) { 'SMTDDCANARY0001' }
    let(:webhook_params) { { 'From' => from, 'To' => to, 'Body' => body, 'MessageSid' => message_sid } }

    around do |example|
      previous = ENV.fetch('TWILIO_AUTH_TOKEN', nil)
      ENV['TWILIO_AUTH_TOKEN'] = auth_token
      example.run
    ensure
      ENV['TWILIO_AUTH_TOKEN'] = previous
    end

    before do
      ActiveJob::Base.queue_adapter = :test
      stub_scheduled_set([])
    end

    def sign(params, token: auth_token, url: webhook_url)
      Twilio::Security::RequestValidator.new(token).build_signature_for(url, params)
    end

    def post_webhook(params = webhook_params, signature: sign(params))
      headers = signature.nil? ? {} : { 'X-Twilio-Signature' => signature }
      post v1_sms_replay_path, params: params, headers: headers
    end

    describe 'signature verification' do
      it 'valid signature: 200 and the STOP takes effect' do
        expect { post_webhook }.to change { SmsOptOut.where(user_id: user.id).count }.from(0).to(1)
        expect(response).to have_http_status(:ok)
      end

      it 'valid signature: response is TwiML XML' do
        post_webhook
        expect(response.headers['Content-Type']).to include('application/xml')
      end

      context 'with an invalid signature' do
        it 'is rejected with 401 or 403' do
          post_webhook(signature: 'not-a-valid-signature')
          expect(response.status).to be_in([401, 403])
        end

        it 'creates no SmsOptOut' do
          expect { post_webhook(signature: 'not-a-valid-signature') }.not_to change(SmsOptOut, :count)
        end

        it 'enqueues no job' do
          expect { post_webhook(signature: 'not-a-valid-signature') }.not_to have_enqueued_job
        end

        it 'does not delete queued jobs' do
          job = fake_send_sms_job_for(from)
          stub_scheduled_set([job])
          post_webhook(signature: 'not-a-valid-signature')
          expect(job).not_to be_deleted
        end

        it 'does not remove an existing opt-out on a forged START' do
          create(:pdp_sms_opt_out, user: user)
          forged = webhook_params.merge('Body' => 'START')
          expect { post_webhook(forged, signature: 'forged') }.not_to change(SmsOptOut, :count)
        end
      end

      context 'without the X-Twilio-Signature header' do
        it 'is rejected with 401 or 403' do
          post_webhook(signature: nil)
          expect(response.status).to be_in([401, 403])
        end

        it 'creates no SmsOptOut' do
          expect { post_webhook(signature: nil) }.not_to change(SmsOptOut, :count)
        end

        it 'enqueues no job' do
          expect { post_webhook(webhook_params.merge('Body' => '1'), signature: nil) }.not_to have_enqueued_job
        end
      end

      context 'with an empty X-Twilio-Signature header' do
        it 'pusty naglowek podpisu: 401/403 i zero skutkow' do
          post_webhook(signature: '')
          expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
          expect(SmsOptOut.exists?(user_id: user.id)).to be(false)
        end
      end

      context 'with a signature computed for a different From' do
        it 'podpis wazny dla innego From (podszycie): odrzucony, zero skutkow' do
          sig = sign(webhook_params.merge('From' => '+12015550124'))
          post_webhook(webhook_params, signature: sig)
          expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
          expect(SmsOptOut.exists?(user_id: user.id)).to be(false)
        end
      end

      context 'with a signature made with a different secret' do
        it 'is rejected and has no effect' do
          expect { post_webhook(signature: sign(webhook_params, token: 'some_other_token')) }.not_to change(SmsOptOut, :count)
          expect(response.status).to be_in([401, 403])
        end
      end

      context 'with a signature computed for a different body than the one sent' do
        it 'is rejected and has no effect (signature covers the sent parameters)' do
          signed_for_help = sign(webhook_params.merge('Body' => 'HELP'))
          expect { post_webhook(webhook_params, signature: signed_for_help) }.not_to change(SmsOptOut, :count)
          expect(response.status).to be_in([401, 403])
        end
      end

      context 'with a signature computed for a different URL' do
        it 'is rejected and has no effect' do
          wrong = sign(webhook_params, url: 'http://www.example.com/v1/other')
          expect { post_webhook(webhook_params, signature: wrong) }.not_to change(SmsOptOut, :count)
          expect(response.status).to be_in([401, 403])
        end
      end
    end

    describe 'over HTTP with a valid signature' do
      it 'START removes the opt-out' do
        create(:pdp_sms_opt_out, user: user)
        expect { post_webhook(webhook_params.merge('Body' => 'START', 'MessageSid' => 'SMTDDCANARY0002')) }
          .to change { SmsOptOut.where(user_id: user.id).count }.from(1).to(0)
      end

      it 'a message containing "stop" only as a substring does not opt out' do
        expect { post_webhook(webhook_params.merge('Body' => 'I will stop by later')) }.not_to change(SmsOptOut, :count)
      end

      it 'a message without "stop" does not opt out' do
        expect { post_webhook(webhook_params.merge('Body' => 'I am fine thanks')) }.not_to change(SmsOptOut, :count)
      end

      it 'HELP answers with a TwiML message and changes no state' do
        create(:pdp_sms_opt_out, user: user)
        expect { post_webhook(webhook_params.merge('Body' => 'HELP')) }.not_to change(SmsOptOut, :count)
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(%r{<Message>\s*\S.*</Message>}m)
      end
    end

    describe 'idempotency on MessageSid' do
      it 'a replayed STOP does not create a second row' do
        create(:pdp_sms_opt_out, user: user)
        post_webhook
        post_webhook
        expect(SmsOptOut.where(user_id: user.id).count).to eq(1)
      end

      it 'a replayed STOP with the same MessageSid answers 200 both times and leaves exactly one row' do
        post_webhook
        first_status = response.status
        post_webhook
        expect([first_status, response.status, SmsOptOut.where(user_id: user.id).count]).to eq([200, 200, 1])
      end

      it 'a replayed STOP does not move opted_out_at' do
        t0 = Time.zone.local(2026, 11, 1, 12, 0, 0)
        travel_to(t0) { post_webhook }
        travel_to(t0 + 2.days) { post_webhook }
        expect(SmsOptOut.find_by(user_id: user.id).opted_out_at).to be_within(1.second).of(t0)
      end

      it 'a replayed START with the same MessageSid does not delete an opt-out created after the first delivery' do
        create(:pdp_sms_opt_out, user: user)
        start = webhook_params.merge('Body' => 'START', 'MessageSid' => 'SMTDDCANARY0003')
        post_webhook(start)
        expect(SmsOptOut.where(user_id: user.id)).to be_empty

        create(:pdp_sms_opt_out, user: user)
        post_webhook(start)
        expect(response).to have_http_status(:ok)
        expect(SmsOptOut.where(user_id: user.id).count).to eq(1)
      end

      it 'a replayed message with the same MessageSid does not enqueue a second job' do
        reply = webhook_params.merge('Body' => '1', 'MessageSid' => 'SMTDDCANARY0004')
        post_webhook(reply)
        expect { post_webhook(reply) }.not_to have_enqueued_job(SmsPlans::SendSmsJob)
        expect(response).to have_http_status(:ok)
      end

      it 'the first delivery with that MessageSid does enqueue the job (control)' do
        reply = webhook_params.merge('Body' => '1', 'MessageSid' => 'SMTDDCANARY0005')
        expect { post_webhook(reply) }.to have_enqueued_job(SmsPlans::SendSmsJob)
      end

      it 'a replayed STOP does not delete queued jobs a second time' do
        post_webhook
        job = fake_send_sms_job_for(from)
        stub_scheduled_set([job])
        post_webhook
        expect(job).not_to be_deleted
      end

      it 'a different MessageSid with the same content is processed (key is the sid, not the body)' do
        post_webhook(webhook_params.merge('Body' => 'STOP', 'MessageSid' => 'SMTDDCANARY0006'))
        post_webhook(webhook_params.merge('Body' => 'START', 'MessageSid' => 'SMTDDCANARY0007'))
        expect(SmsOptOut.where(user_id: user.id)).to be_empty
      end

      it 'a STOP, START, STOP sequence with distinct sids ends opted out' do
        %w[STOP START STOP].each_with_index do |text, i|
          post_webhook(webhook_params.merge('Body' => text, 'MessageSid' => "SMTDDCANARYSEQ#{i}"))
        end
        expect(SmsOptOut.where(user_id: user.id).count).to eq(1)
      end

      it 'a duplicate with an invalid signature is still rejected, not treated as a duplicate' do
        post_webhook
        post_webhook(signature: 'forged')
        expect(response.status).to be_in([401, 403])
      end
    end
  end
end
