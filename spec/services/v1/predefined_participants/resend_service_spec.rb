# frozen_string_literal: true

require 'rails_helper'
require 'support/predefined_participant_sms_helpers'

RSpec.describe 'V1::PredefinedParticipants::ResendService' do
  include PredefinedParticipantSmsHelpers

  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :published, user: researcher) }
  let(:invited_at) { Time.zone.parse('2026-10-20 09:00:00') }
  let!(:pup) { make_participant(intervention, index: 0, invited_at: invited_at) }
  let(:participant) { pup.user }
  let(:provider_fails) { false }
  let(:web_host) { 'https://web.example.test' }
  let(:stored_body) { "#{canary_body} #{web_host}/link/#{canary_slug}" }
  let(:campaign) do
    create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent', sent_at: invited_at, created_at: frozen_now - 2.days)
  end
  let(:delivery) do
    create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, body: stored_body, status: 'sent', sent_at: invited_at,
                              created_at: frozen_now - 2.days)
  end

  def service_class
    'V1::PredefinedParticipants::ResendService'.constantize
  end

  def resend(target = participant)
    travel_to(frozen_now) { service_class.call(target) }
  end

  def last_message
    Message.order(:created_at, :id).last
  end

  def raised
    yield
    nil
  rescue NameError
    raise
  rescue StandardError => e
    e
  end

  before do
    stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_host))
    allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true) unless provider_fails
  end

  describe 'resends the stored text' do
    it 'sends the body of the participant invitation delivery literally' do
      delivery
      expect { resend }.to change(Message, :count).by(1)
      expect(last_message.body).to eq(stored_body)
    end

    it 'sends to the participant phone number' do
      delivery
      resend
      expect(last_message.phone).to eq(participant.phone.full_number)
    end

    it 'keeps the same personal slug inside the resent text' do
      body = "#{canary_body} #{web_host}/usr/#{pup.slug}"
      delivery.update!(body: body)
      resend
      expect(last_message.body).to eq(body)
      expect(last_message.body).to include(pup.slug)
    end

    it 'takes the body of the latest invitation delivery, not an older one' do
      older_campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'failed', created_at: frozen_now - 5.days)
      create(:pdp_sms_delivery, campaign: older_campaign, predefined_user_parameter: pup, body: 'CIAS_TDD_OLDER_BODY', status: 'failed',
                                created_at: frozen_now - 5.days)
      delivery
      resend
      expect(last_message.body).to eq(stored_body)
    end

    it 'takes the latest invitation delivery even when that delivery failed' do
      delivery
      retry_campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'failed', created_at: frozen_now - 1.day)
      create(:pdp_sms_delivery, campaign: retry_campaign, predefined_user_parameter: pup, body: 'CIAS_TDD_FAILED_BODY', status: 'failed',
                                created_at: frozen_now - 1.day)
      resend
      expect(last_message.body).to eq('CIAS_TDD_FAILED_BODY')
    end

    it 'ignores the delivery of a newer reminder campaign' do
      delivery
      reminder = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sent', created_at: frozen_now - 1.day)
      create(:pdp_sms_delivery, campaign: reminder, predefined_user_parameter: pup, body: 'CIAS_TDD_REMINDER_BODY', status: 'sent',
                                created_at: frozen_now - 1.day)
      resend
      expect(last_message.body).to eq(stored_body)
    end

    it 'does not take the body of another participant delivery' do
      other = make_participant(intervention, index: 1, invited_at: invited_at)
      create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: other, body: 'CIAS_TDD_OTHER_PARTICIPANT_BODY',
                                status: 'sent', created_at: frozen_now - 1.hour)
      delivery
      resend
      expect(last_message.body).to eq(stored_body)
    end
  end

  describe 'fallback to the locale text' do
    let(:fallback_text) do
      I18n.with_locale(intervention.language_code) do
        I18n.t('predefined_participant.invitation', intervention_name: intervention.name, link: "#{web_host}/usr/#{pup.slug}")
      end
    end

    it 'sends the locale invitation text when the participant has no delivery' do
      expect { resend }.to change(Message, :count).by(1)
      expect(last_message.body).to eq(fallback_text)
    end

    it 'includes the intervention name and the personal link in the fallback text' do
      resend
      expect(last_message.body).to include(intervention.name, "#{web_host}/usr/#{pup.slug}")
    end

    it 'creates no delivery row for the fallback' do
      expect { resend }.not_to change(PredefinedParticipants::SmsDelivery, :count)
    end

    it 'does not fall back when the only invitation delivery failed, it resends the stored text' do
      failed_campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'failed')
      create(:pdp_sms_delivery, campaign: failed_campaign, predefined_user_parameter: pup, body: 'CIAS_TDD_FAILED_BODY', status: 'failed')
      resend
      expect(last_message.body).to eq('CIAS_TDD_FAILED_BODY')
    end

    it 'falls back when the only delivery belongs to a reminder campaign' do
      reminder = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sent')
      create(:pdp_sms_delivery, campaign: reminder, predefined_user_parameter: pup, body: 'CIAS_TDD_REMINDER_BODY', status: 'sent')
      resend
      expect(last_message.body).to eq(fallback_text)
    end
  end

  describe 'bookkeeping on the existing delivery' do
    before { delivery }

    it 'does not insert another delivery row' do
      expect { resend }.not_to change(PredefinedParticipants::SmsDelivery, :count)
    end

    it 'increments resend_count by one' do
      expect { resend }.to change { delivery.reload.resend_count }.from(0).to(1)
    end

    it 'counts every further resend' do
      resend
      resend
      expect(delivery.reload.resend_count).to eq(2)
    end

    it 'sets last_resent_at' do
      expect { resend }.to change { delivery.reload.last_resent_at }.from(nil).to(be_within(1.second).of(frozen_now))
    end

    it 'leaves the stored body, status and sent_at of the delivery alone' do
      expect { resend }.not_to(change { delivery.reload.slice(:body, :status, :sent_at, :campaign_id, :predefined_user_parameter_id) })
    end

    it 'does not touch the campaign counters' do
      campaign.update!(recipients_count: 3, accepted_count: 3)
      expect { resend }.not_to(change { campaign.reload.slice(:status, :recipients_count, :accepted_count, :failed_count, :sent_at) })
    end
  end

  describe 'a participant who has not received an SMS invitation' do
    let!(:pup) { make_participant(intervention, index: 0, invited_at: nil) }

    it 'sends the locale invitation text and stamps sms_invitation_sent_at' do
      expect { resend }.to change(Message, :count).by(1)
      expect(last_message.body).to include("/usr/#{pup.slug}")
      expect(pup.reload.sms_invitation_sent_at).to eq(frozen_now)
    end

    context 'when the provider rejects the message' do
      let(:provider_fails) { true }

      before do
        allow_any_instance_of(Twilio::REST::Api::V2010::AccountContext::MessageList).to receive(:create).and_raise(StandardError, 'rejected')
      end

      it 'does not stamp sms_invitation_sent_at, so the participant can be invited again' do
        expect(raised { resend }).to be_a(ComplexException)
        expect(pup.reload.sms_invitation_sent_at).to be_nil
      end
    end
  end

  describe 'does not restamp the invitation' do
    it 'keeps sms_invitation_sent_at when the participant has a delivery' do
      delivery
      expect { resend }.not_to(change { pup.reload.sms_invitation_sent_at })
      expect(pup.reload.sms_invitation_sent_at).to be_within(1.second).of(invited_at)
    end

    it 'keeps sms_invitation_sent_at on the fallback path' do
      expect { resend }.not_to(change { pup.reload.sms_invitation_sent_at })
      expect(pup.reload.sms_invitation_sent_at).to be_within(1.second).of(invited_at)
    end

    it 'keeps last_reminder_sent_at untouched' do
      delivery
      expect { resend }.not_to(change { pup.reload.last_reminder_sent_at })
    end
  end

  describe 'requires a published intervention' do
    {
      'draft' => ['INTERVENTION_DRAFT', {}],
      'paused' => ['INTERVENTION_PAUSED', { status: 'paused' }],
      'closed' => ['INTERVENTION_CLOSED', { status: 'closed' }]
    }.each do |label, (reason, attributes)|
      context "when the intervention is #{label}" do
        let(:intervention) { create(:intervention, user: researcher, **attributes) }

        before { delivery }

        it "raises a 400 ComplexException with reason #{reason}" do
          exception = capture_complex_exception { resend }
          expect(exception).to be_a(ComplexException)
          expect(http_status(exception)).to eq(400)
          expect(exception.additional_information.with_indifferent_access[:reason]).to eq(reason)
        end

        it 'sends nothing and records nothing' do
          expect { capture_complex_exception { resend } }.not_to change(Message, :count)
          expect(delivery.reload.resend_count).to eq(0)
          expect(delivery.last_resent_at).to be_nil
        end
      end
    end

    it 'also refuses the fallback path for an unpublished intervention' do
      draft = create(:intervention, user: researcher)
      draft_pup = make_participant(draft, index: 2, invited_at: invited_at)
      exception = capture_complex_exception { resend(draft_pup.user) }
      expect(exception).to be_a(ComplexException)
      expect(exception.additional_information.with_indifferent_access[:reason]).to eq('INTERVENTION_DRAFT')
    end
  end

  describe 'resend interval for a participant without an invitation delivery' do
    let(:interval) { 60.minutes }

    def resend_within_interval(at: frozen_now)
      travel_to(at) { service_class.call(participant, min_interval: interval) }
    end

    it 'refuses a second resend within the interval and sends nothing' do
      resend_within_interval
      error = nil
      expect { error = raised { resend_within_interval(at: frozen_now + 59.minutes) } }.not_to change(Message, :count)
      expect(error).to be_a(ComplexException)
      expect(error.status_code).to eq(:too_many_requests)
      expect(error.additional_information[:errors]).to eq([{ code: 'RESEND_TOO_SOON' }])
      expect(error.additional_information[:retry_after]).to eq(60)
    end

    it 'accepts a resend once the interval has passed' do
      resend_within_interval
      expect { resend_within_interval(at: frozen_now + 61.minutes) }.to change(Message, :count).by(1)
    end

    it 'records the resend on the participant and keeps sms_invitation_sent_at' do
      resend_within_interval
      expect(pup.reload.last_resent_at).to be_within(1.second).of(frozen_now)
      expect(pup.sms_invitation_sent_at).to be_within(1.second).of(invited_at)
    end

    it 'does not apply the interval of another participant' do
      other = make_participant(intervention, index: 1, invited_at: invited_at)
      resend_within_interval
      expect { travel_to(frozen_now) { service_class.call(other.user, min_interval: interval) } }.to change(Message, :count).by(1)
    end

    context 'when the provider fails' do
      let(:provider_fails) { true }

      before do
        messages = double('twilio messages')
        allow(messages).to receive(:create).and_raise(StandardError, 'CIAS_TDD_RAW_PROVIDER_TEXT')
        allow(Twilio::REST::Client).to receive(:new).and_return(double('twilio client', messages: messages))
      end

      it 'releases the interval so the resend can be retried at once' do
        expect(raised { resend_within_interval }).not_to be_nil
        expect(pup.reload.last_resent_at).to be_nil
      end
    end
  end

  describe 'resend interval across invitation deliveries' do
    let(:interval) { 60.minutes }

    def resend_within_interval(at:)
      travel_to(at) { service_class.call(participant, min_interval: interval) }
    end

    it 'refuses a resend within the interval after the pending invitation delivery is sent' do
      delivery.update_columns(status: 'pending', sent_at: nil)
      resend_within_interval(at: frozen_now)
      delivery.update_columns(status: 'sent', sent_at: frozen_now)
      error = nil
      expect { error = raised { resend_within_interval(at: frozen_now + 10.minutes) } }.not_to change(Message, :count)
      expect(error).to be_a(ComplexException)
      expect(error.status_code).to eq(:too_many_requests)
    end

    it 'refuses a resend within the interval after a newer invitation delivery is sent' do
      delivery
      resend_within_interval(at: frozen_now)
      newer_campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent', sent_at: frozen_now,
                                                 created_at: frozen_now + 1.minute)
      create(:pdp_sms_delivery, campaign: newer_campaign, predefined_user_parameter: pup, body: stored_body, status: 'sent', sent_at: frozen_now,
                                created_at: frozen_now + 1.minute)
      error = nil
      expect { error = raised { resend_within_interval(at: frozen_now + 10.minutes) } }.not_to change(Message, :count)
      expect(error).to be_a(ComplexException)
      expect(error.status_code).to eq(:too_many_requests)
    end

    it 'counts the resend on the invitation delivery' do
      delivery
      resend_within_interval(at: frozen_now)
      expect(delivery.reload).to have_attributes(resend_count: 1, last_resent_at: be_within(1.second).of(frozen_now))
    end
  end

  describe 'provider failure' do
    let(:provider_text) { 'CIAS_TDD_RAW_PROVIDER_TEXT The To number +12015550123 is not a valid phone number' }
    let(:messages) { double('twilio messages') }
    let(:provider_fails) { true }

    before do
      delivery
      allow(messages).to receive(:create).and_raise(StandardError, provider_text)
      allow(Twilio::REST::Client).to receive(:new).and_return(double('twilio client', messages: messages))
    end

    it 'does not report a provider failure as a successful resend' do
      expect(raised { resend }).not_to be_nil
    end

    it 'does not restamp the invitation after a provider failure' do
      raised { resend }
      expect(pup.reload.sms_invitation_sent_at).to be_within(1.second).of(invited_at)
    end

    it 'the error carries neither the phone number nor the raw provider text' do
      error = raised { resend }
      expect(error).not_to be_nil
      texts = [error.message.to_s, error.try(:additional_information).to_s]
      expect(texts.join(' ')).not_to include('+12015550123', '2015550123', 'CIAS_TDD_RAW_PROVIDER_TEXT', 'not a valid phone number')
    end
  end

  describe 'resend body, slug and interval' do
    let(:slug_body) { "#{canary_body} #{web_host}/usr/#{canary_slug}" }

    def graft_invitation_delivery(body:, created_at:, target: pup, intervention_for_campaign: intervention)
      graft_campaign = create(:pdp_sms_campaign, intervention: intervention_for_campaign, kind: 'invitation',
                                                 status: 'sent', sent_at: created_at, created_at: created_at)
      create(:pdp_sms_delivery, campaign: graft_campaign, predefined_user_parameter: target, body: body,
                                status: 'sent', sent_at: created_at, created_at: created_at)
    end

    it 'hands the stored text to the SMS gateway (the provider client receives the same body)' do
      graft_invitation_delivery(body: slug_body, created_at: Time.zone.parse('2026-10-15 09:00:00'))
      client = instance_double(Twilio::REST::Client)
      messages = double('messages')
      allow(Twilio::REST::Client).to receive(:new).and_return(client)
      allow(client).to receive(:messages).and_return(messages)
      allow(messages).to receive(:create)
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_call_original
      resend
      expect(messages).to have_received(:create).with(hash_including(body: slug_body, to: participant.phone.full_number))
    end

    it 'touches only the latest invitation delivery, not an older one' do
      latest = graft_invitation_delivery(body: slug_body, created_at: Time.zone.parse('2026-10-15 09:00:00'))
      older = graft_invitation_delivery(body: 'CIAS_TDD_OLD_BODY', created_at: Time.zone.parse('2026-10-05 09:00:00'))
      resend
      expect(latest.reload.resend_count).to eq(1)
      expect(older.reload).to have_attributes(resend_count: 0, last_resent_at: nil)
    end

    it 'does not touch the delivery of another participant' do
      graft_invitation_delivery(body: slug_body, created_at: Time.zone.parse('2026-10-15 09:00:00'))
      other = make_participant(intervention, index: 1)
      other_delivery = graft_invitation_delivery(body: 'CIAS_TDD_OTHER_PARTICIPANT_BODY',
                                                 created_at: Time.zone.parse('2026-10-16 09:00:00'), target: other)
      resend
      expect(other_delivery.reload).to have_attributes(resend_count: 0, last_resent_at: nil)
    end

    it 'the very same setup is resent when the intervention is published' do
      graft_invitation_delivery(body: slug_body, created_at: Time.zone.parse('2026-10-15 09:00:00'))
      expect { resend }.to change(Message, :count).by(1)
    end

    it 'is not the legacy class and does not change the signature of SendSmsInvitation' do
      expect(service_class).not_to eq(V1::Intervention::PredefinedParticipants::SendSmsInvitation)
      expect(V1::Intervention::PredefinedParticipants::SendSmsInvitation.method(:call).arity).to eq(1)
    end

    it 'does not call SendSmsInvitation (which would stamp sms_invitation_sent_at)' do
      allow(V1::Intervention::PredefinedParticipants::SendSmsInvitation).to receive(:call).and_call_original
      resend
      expect(V1::Intervention::PredefinedParticipants::SendSmsInvitation).not_to have_received(:call)
    end
  end
end
