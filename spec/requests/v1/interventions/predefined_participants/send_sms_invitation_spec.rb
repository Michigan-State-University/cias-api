# frozen_string_literal: true

require 'rails_helper'
require 'support/predefined_participant_sms_helpers'
require 'support/scheduled_sms_helpers'

RSpec.describe 'POST /v1/interventions/:intervention_id/predefined_participants/:id/sms_send_invitation', type: :request do
  context 'when the SMS provider accepts every message' do
    let!(:intervention) { create(:intervention, :published, :with_predefined_participants, user: researcher) }
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:user) { intervention.predefined_users.first }
    let(:user_id) { user.id }
    let(:current_user) { researcher }
    let(:request) do
      post send_sms_invitation_v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user_id),
           headers: current_user.create_new_auth_token
    end

    before do
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
    end

    it 'return correct body' do
      request
      expect(json_response['invitation_sent_at']).to be_nil
    end

    it 'skip creation of message' do
      expect { request }.not_to change(Message, :count)
    end

    context 'when user has assigned phone' do
      before do
        user.create_phone(iso: 'PL', prefix: '+48', number: '512345678')
        user.predefined_user_parameter.update!(sms_invitation_sent_at: 1.day.ago)
      end

      it 'return correct status' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'return correct body' do
        request
        expect(json_response['sms_invitation_sent_at']).to be_present
      end

      it 'skip creation of message' do
        expect { request }.to change(Message, :count).by(1)
      end
    end

    context 'when the participant has a phone but has not received an SMS invitation' do
      before { user.create_phone(iso: 'PL', prefix: '+48', number: '512345678') }

      it 'sends the first invitation and stamps sms_invitation_sent_at' do
        expect { request }.to change(Message, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(json_response['sms_invitation_sent_at']).to be_present
      end
    end

    context 'when id is wrong' do
      let(:user_id) { 'wrongId' }

      it 'return correct status' do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    it_behaves_like 'users without access'
  end

  describe 'authentication, current editor gate and resend stamp' do
    include PredefinedParticipantSmsHelpers

    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:current_user) { researcher }
    let!(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:pup) { make_participant(intervention, index: 0, invited_at: Time.zone.parse('2026-10-20 09:00:00')) }
    let(:participant_id) { pup.user.id }
    let(:base) { "/v1/interventions/#{intervention.id}/predefined_participants/#{participant_id}" }
    let(:sms_path) { "#{base}/send_sms_invitation" }
    let(:email_path) { "#{base}/send_email_invitation" }
    let(:provider_fails) { false }
    let(:collaborator) { create(:user, :researcher, :confirmed) }

    before do
      stub_const('ENV', ENV.to_hash.merge('WEB_URL' => 'https://web.example.test'))
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true) unless provider_fails
    end

    def invitation_delivery(body: "#{canary_body} https://web.example.test/link/#{canary_slug}")
      campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent', created_at: 2.days.ago)
      create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, body: body, status: 'sent', created_at: 2.days.ago)
    end

    describe 'send_sms_invitation (resend)' do
      let(:request) { post sms_path, headers: current_user.create_new_auth_token }

      it 'answers 401 without a token' do
        post sms_path
        expect(response).to have_http_status(:unauthorized)
      end

      it_behaves_like 'users without access'

      context 'with a collaborator who has edit: true' do
        before { create(:collaborator, intervention: intervention, user: collaborator, edit: true, view: true) }

        it 'answers 403 when the collaborator is not the current editor' do
          intervention.update!(current_editor: researcher)
          post sms_path, headers: collaborator.create_new_auth_token
          expect(response).to have_http_status(:forbidden)
        end

        it 'sends no message for the non-editor' do
          intervention.update!(current_editor: researcher)
          expect { post sms_path, headers: collaborator.create_new_auth_token }.not_to change(Message, :count)
        end

        it 'answers 403 when nobody is the current editor' do
          post sms_path, headers: collaborator.create_new_auth_token
          expect(response).to have_http_status(:forbidden)
        end

        it 'the same collaborator gets 200 once they are the current editor' do
          intervention.update!(current_editor: collaborator)
          post sms_path, headers: collaborator.create_new_auth_token
          expect(response).to have_http_status(:ok)
        end
      end

      describe 'goes through the resend path' do
        it 'resends the stored delivery body literally' do
          delivery = invitation_delivery
          expect { request }.to change(Message, :count).by(1)
          expect(response).to have_http_status(:ok)
          expect(Message.order(:created_at, :id).last.body).to eq(delivery.body)
        end

        it 'increments resend_count on the existing delivery without adding a row' do
          delivery = invitation_delivery
          expect { request }.not_to change(PredefinedParticipants::SmsDelivery, :count)
          expect(delivery.reload.resend_count).to eq(1)
        end

        it 'does not restamp sms_invitation_sent_at' do
          invitation_delivery
          expect { request }.not_to(change { pup.reload.sms_invitation_sent_at })
        end
      end

      describe 'intervention state' do
        {
          'draft' => %w[INTERVENTION_DRAFT draft],
          'paused' => %w[INTERVENTION_PAUSED paused],
          'closed' => %w[INTERVENTION_CLOSED closed]
        }.each do |label, (reason, status)|
          it "answers 400 with details.reason #{reason} for a #{label} intervention" do
            intervention.update_column(:status, status)
            request
            expect(response).to have_http_status(:bad_request)
            expect(json_response['details']).to eq('reason' => reason)
          end
        end
      end

      describe 'provider failure' do
        let(:provider_fails) { true }
        let(:provider_text) { 'CIAS_TDD_RAW_PROVIDER_TEXT The To number +12015550123 is not a valid phone number' }
        let(:messages) { double('twilio messages') }

        before do
          invitation_delivery
          allow(messages).to receive(:create).and_raise(StandardError, provider_text)
          allow(Twilio::REST::Client).to receive(:new).and_return(double('twilio client', messages: messages))
        end

        it 'does not answer with a success status' do
          request
          expect(response.status).to be >= 400
        end

        it 'leaves sms_invitation_sent_at untouched' do
          expect { request }.not_to(change { pup.reload.sms_invitation_sent_at })
        end

        it 'never puts the phone number or the raw provider text in the response' do
          request
          expect(response.status).to be >= 400
          expect(response.body).not_to include('+12015550123', '2015550123', 'CIAS_TDD_RAW_PROVIDER_TEXT', 'not a valid phone number')
        end
      end
    end

    describe 'resend gate and stamp' do
      let(:request) { post sms_path, headers: current_user.create_new_auth_token }
      let!(:delivery) { invitation_delivery }

      it 'answers with the unchanged sms_invitation_sent_at' do
        request
        expect(response).to have_http_status(:ok)
        expect(Time.zone.parse(json_response['sms_invitation_sent_at'])).to eq(Time.zone.parse('2026-10-20 09:00:00'))
      end

      it 'sends nothing and moves no counter for another researcher' do
        other = create(:user, :researcher, :confirmed)
        expect { post sms_path, headers: other.create_new_auth_token }.not_to change(Message, :count)
        expect(delivery.reload.resend_count).to eq(0)
      end

      context 'when the provider raises' do
        let(:provider_fails) { true }
        let(:provider_text) { 'CIAS_TDD_TWILIO_RAW_ERROR The number +12015550123 is unverified' }
        let(:messages_api) { double('messages') }

        before do
          client = instance_double(Twilio::REST::Client)
          allow(Twilio::REST::Client).to receive(:new).and_return(client)
          allow(client).to receive(:messages).and_return(messages_api)
          allow(messages_api).to receive(:create).and_raise(StandardError, provider_text)
        end

        it 'reaches the provider (so the leak checks are not vacuous)' do
          request
          expect(messages_api).to have_received(:create).once
        end

        it 'keeps the stored body and its personal link out of an error response' do
          request
          expect(messages_api).to have_received(:create)
          expect(response.body).not_to include(canary_slug)
        end
      end
    end
  end

  describe 'resend interval' do
    include_context 'with real rack attack store'

    let(:researcher) { create(:user, :researcher, :confirmed) }
    let!(:intervention) { create(:intervention, :published, :with_predefined_participants, user: researcher) }
    let(:participant) { intervention.predefined_users.first }
    let(:other_participant) { intervention.predefined_users.second }

    let(:campaign) do
      create(:pdp_sms_campaign, :scheduled, intervention: intervention, kind: 'invitation', status: 'sent', sent_at: 2.days.ago,
                                            scheduled_at: 2.days.ago, recipients_count: 2, accepted_count: 2)
    end

    before do
      create_us_phone!(participant, 0)
      create_us_phone!(other_participant, 1)
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
      [participant, other_participant].each do |user|
        user.predefined_user_parameter.update!(sms_invitation_sent_at: 2.days.ago)
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: user.predefined_user_parameter,
                                  status: 'sent', sent_at: 2.days.ago)
      end
    end

    def resend(user, as_user: researcher)
      post send_sms_invitation_v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user.id),
           headers: as_user.create_new_auth_token
    end

    it 'accepts the first resend' do
      resend(participant)
      expect(response).to have_http_status(:ok)
    end

    it 'answers a second resend to the same participant within an hour with 429 and sends nothing' do
      resend(participant)
      expect(response).to have_http_status(:ok)

      expect { resend(participant) }.not_to change(Message, :count)
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'still refuses 59 minutes after the first resend' do
      resend(participant)
      travel 59.minutes

      expect { resend(participant) }.not_to change(Message, :count)
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'accepts a resend to the same participant once the hour has passed' do
      resend(participant)
      travel 61.minutes

      expect { resend(participant) }.to change(Message, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'does not block a different participant (the interval is per participant)' do
      resend(participant)
      resend(participant)
      expect(response).to have_http_status(:too_many_requests)

      expect { resend(other_participant) }.to change(Message, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'applies the interval whoever triggers the resend (another editor of the same intervention)' do
      resend(participant)
      other = create(:collaborator, intervention: intervention, edit: true, view: true).user
      intervention.update!(current_editor: other)

      resend(participant, as_user: other)
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'a throttled resend does not touch the delivery counters' do
      resend(participant)
      delivery = PredefinedParticipants::SmsDelivery.find_by!(predefined_user_parameter_id: participant.predefined_user_parameter.id)
      expect(delivery.resend_count).to eq(1)

      resend(participant)

      expect(delivery.reload.resend_count).to eq(1)
    end

    context 'when the participant was invited at publish and has no invitation delivery' do
      let(:publish_invited) { intervention.predefined_users.third }

      before do
        create_us_phone!(publish_invited, 2)
        publish_invited.predefined_user_parameter.update!(sms_invitation_sent_at: 2.days.ago)
      end

      it 'answers a second resend within an hour with 429 and sends nothing' do
        resend(publish_invited)
        expect(response).to have_http_status(:ok)

        expect { resend(publish_invited) }.not_to change(Message, :count)
        expect(response).to have_http_status(:too_many_requests)
      end

      it 'accepts a resend once the hour has passed' do
        resend(publish_invited)
        travel 61.minutes

        expect { resend(publish_invited) }.to change(Message, :count).by(1)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'opted-out and SMS-ineligible participants' do
    include ScheduledSmsHelpers

    let(:researcher) { create(:user, :researcher, :confirmed) }
    let!(:intervention) { create(:intervention, :published, :with_predefined_participants, user: researcher) }
    let(:participant) { intervention.predefined_users.first }
    let!(:phone) { create(:phone, :confirmed, user: participant) }
    let!(:sms_calls) { stub_sms_provider }
    let(:invited_at) { Time.zone.parse('2026-10-20 09:00:00') }
    let(:request) do
      post send_sms_invitation_v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: participant.id),
           headers: researcher.create_new_auth_token
    end

    before { participant.predefined_user_parameter.update!(sms_invitation_sent_at: invited_at) }

    def stamp
      participant.predefined_user_parameter.reload.sms_invitation_sent_at
    end

    it 'an eligible participant who is not opted out gets the message' do
      expect { request }.to change(Message, :count).by(1)
      expect(sms_calls.size).to eq(1)
    end

    context 'when the participant is opted out' do
      before { create(:pdp_sms_opt_out, user: participant) }

      it 'sends no message' do
        expect { request }.not_to change(Message, :count)
      end

      it 'does not reach the SMS provider' do
        request
        expect(sms_calls).to be_empty
      end

      it 'leaves sms_invitation_sent_at as it was' do
        request
        expect(stamp).to eq(invited_at)
      end

      it 'does not crash the endpoint' do
        request
        expect(response.status).to be < 500
      end

      it 'keeps the opt-out row' do
        expect { request }.not_to change(SmsOptOut, :count)
      end
    end

    context 'when the participant was opted out and then sent START' do
      it 'the resend goes through again' do
        create(:pdp_sms_opt_out, user: participant).destroy!
        expect { request }.to change(Message, :count).by(1)
      end
    end

    context 'when the number is not sms_eligible' do
      before { phone.update_column(:sms_eligible, false) }

      it 'sends no message' do
        expect { request }.not_to change(Message, :count)
      end

      it 'does not reach the provider and leaves sms_invitation_sent_at as it was' do
        request
        expect([sms_calls.size, stamp]).to eq([0, invited_at])
      end

      it 'does not crash the endpoint' do
        request
        expect(response.status).to be < 500
      end
    end
  end
end
