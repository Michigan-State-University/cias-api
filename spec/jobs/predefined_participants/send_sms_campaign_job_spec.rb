# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PredefinedParticipants::SendSmsCampaignJob, type: :job do
  context 'with a stubbed Twilio message list' do
    include PredefinedParticipantSmsHelpers

    let(:intervention) { create(:intervention, :published) }
    let(:kind) { 'invitation' }
    let(:status) { 'scheduled' }
    let(:parent_status) { 'sent' }
    let(:campaign_attrs) { {} }
    let(:parent_campaign) do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: parent_status,
                                sent_at: 3.days.ago, accepted_count: 1, scheduled_at: 4.days.ago)
    end
    let(:campaign) do
      attrs = { intervention: intervention, kind: kind, status: status, scheduled_at: 1.hour.ago }
      attrs = attrs.merge(parent_campaign: parent_campaign, days_after: 3) if kind == 'scheduled_reminder'
      create(:pdp_sms_campaign, **attrs, **campaign_attrs)
    end

    let(:provider_calls) { [] }
    let(:twilio_messages) { instance_double(Twilio::REST::Api::V2010::AccountContext::MessageList) }

    before do
      travel_to(frozen_now)
      stub_web_url
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      allow(twilio_messages).to receive(:create) do |**kwargs|
        provider_calls << kwargs
        fake_message
      end
      allow(Twilio::REST::Client).to receive(:new).and_return(Struct.new(:messages).new(twilio_messages))
    end

    def fake_message = Struct.new(:sid).new('SMTDDFAKE')

    def number_for(index) = "+1201555#{format('%04d', 123 + index)}"

    def add_participant(index, **options)
      attrs = options.dup
      attrs[:invited_at] ||= 3.days.ago unless kind == 'invitation'
      make_participant(intervention, index: index, **attrs).tap do |pup|
        next unless kind == 'scheduled_reminder'

        create(:pdp_sms_delivery, campaign: campaign.parent_campaign, predefined_user_parameter: pup, status: 'sent')
      end
    end

    def run_job(target = campaign) = described_class.new.perform(target.id)

    missing_delivery = Struct.new(:status, :error_code, :updated_at, :message) do
      def blank? = true
    end

    define_method(:delivery_of) do |pup|
      PredefinedParticipants::SmsDelivery.find_by(campaign_id: campaign.id, predefined_user_parameter_id: pup.id) ||
        missing_delivery.new
    end

    def attempted_numbers = provider_calls.pluck(:to)

    def campaign_jobs
      ActiveJob::Base.queue_adapter.enqueued_jobs.select { |entry| entry[:job] == described_class }
    end

    def provider_error(number)
      response = Struct.new(:status_code, :body).new(400, { 'code' => 21_211, 'message' => 'invalid' })
      Twilio::REST::RestError.new("Unable to create record: The 'To' number #{number} is not valid. #{canary_body}", response)
    end

    def fail_provider_for(*numbers)
      allow(twilio_messages).to receive(:create) do |**kwargs|
        provider_calls << kwargs
        raise provider_error(kwargs[:to]) if numbers.include?(kwargs[:to])

        fake_message
      end
    end

    def raise_on_sms_new(nth, error)
      calls = 0
      allow(Communication::Sms).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        calls += 1
        raise error, 'injected failure' if calls == nth

        original.call(*args, **kwargs)
      end
    end

    def restore_sms_new = allow(Communication::Sms).to receive(:new).and_call_original

    def capture_log
      io = StringIO.new
      logger = ActiveSupport::Logger.new(io)
      Rails.logger.broadcast_to(logger)
      yield
      io.string
    ensure
      Rails.logger.stop_broadcasting_to(logger)
    end

    describe 'campaign status gate' do
      %w[sent failed cancelled skipped].each do |terminal|
        context "with a #{terminal} campaign" do
          let(:status) { terminal }

          it "sends nothing and changes nothing for a #{terminal} campaign" do
            pup = add_participant(0)
            run_job
            expect(attempted_numbers).to be_empty
            expect(PredefinedParticipants::SmsDelivery.count).to eq(0)
            expect(campaign.reload.status).to eq(terminal)
            expect(pup.reload.sms_invitation_sent_at).to be_nil
          end
        end
      end

      %w[scheduled sending].each do |active|
        context "with a #{active} campaign" do
          let(:status) { active }

          it "a #{active} campaign is processed and its recipient gets the SMS" do
            pup = add_participant(0)
            run_job
            expect(attempted_numbers).to eq([number_for(0)])
            expect(delivery_of(pup).status).to eq('sent')
          end
        end
      end

      it 'a campaign fired before scheduled_at sends nothing and re-enqueues itself 15 minutes later' do
        add_participant(0)
        future = create(:pdp_sms_campaign, intervention: create(:intervention, :published), kind: 'invitation',
                                           scheduled_at: 2.hours.from_now)
        run_job(future)
        expect(provider_calls).to be_empty
        expect(described_class).to have_been_enqueued.with(future.id).at(15.minutes.from_now)
        expect(future.reload.scheduled_at).to be_within(1.second).of(2.hours.from_now)
        expect(future.status).to eq('scheduled')
      end

      it 'a scheduled reminder whose parent is still sending reschedules instead of skipping' do
        pending_parent = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sending',
                                                   scheduled_at: 4.days.ago)
        child = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder',
                                          parent_campaign: pending_parent, days_after: 3, scheduled_at: 1.hour.ago)
        run_job(child)
        expect(provider_calls).to be_empty
        expect(described_class).to have_been_enqueued.with(child.id).at(15.minutes.from_now)
        expect(child.reload.status).to eq('scheduled')
      end

      it 'a scheduled reminder whose parent reached nobody is skipped, not rescheduled' do
        dead_parent = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'failed',
                                                accepted_count: 0, scheduled_at: 4.days.ago)
        child = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder',
                                          parent_campaign: dead_parent, days_after: 3, scheduled_at: 1.hour.ago)
        run_job(child)
        expect(child.reload.status).to eq('skipped')
        expect(provider_calls).to be_empty
        expect(campaign_jobs).to be_empty
      end
    end

    describe 'intervention no longer published' do
      context 'when the intervention is paused' do
        let(:intervention) { create(:intervention, :paused) }

        it 'reschedules the campaign instead of skipping it, so a re-publish can still send it' do
          add_participant(0)
          run_job
          expect(campaign.reload.status).to eq('scheduled')
          expect(provider_calls).to be_empty
          expect(PredefinedParticipants::SmsDelivery.count).to eq(0)
          expect(described_class).to have_been_enqueued.with(campaign.id).at(15.minutes.from_now)
        end
      end

      %i[closed archived].each do |intervention_state|
        context "when the intervention is #{intervention_state}" do
          let(:intervention) { create(:intervention, intervention_state) }

          it "skips the campaign without sending or rescheduling when the intervention is #{intervention_state}" do
            add_participant(0)
            run_job
            expect(campaign.reload.status).to eq('skipped')
            expect(provider_calls).to be_empty
            expect(PredefinedParticipants::SmsDelivery.count).to eq(0)
            expect(campaign_jobs).to be_empty
          end
        end
      end

      it 'the same campaign on a published intervention is not skipped and sends' do
        add_participant(0)
        run_job
        expect(campaign.reload.status).not_to eq('skipped')
        expect(attempted_numbers).to eq([number_for(0)])
      end
    end

    describe 'recipients_count is written on the first run only' do
      it 'the first run stores the size of the set as it was when the run started' do
        3.times { |i| add_participant(i) }
        run_job
        expect(campaign.reload.recipients_count).to eq(3)
      end

      it 'a campaign that already has recipients_count keeps it although the scope has since narrowed' do
        2.times { |i| add_participant(i) }
        campaign.update!(status: 'sending', recipients_count: 7)
        run_job
        expect(attempted_numbers.size).to eq(2)
        expect(campaign.reload.recipients_count).to eq(7)
      end

      it 'a resumed run after a killed first run does not overwrite the count with its narrowed scope' do
        pups = Array.new(3) { |i| add_participant(i) }
        raise_on_sms_new(2, ApplicationJob::JobTimeoutError)
        expect { run_job }.to raise_error(ApplicationJob::JobTimeoutError)
        expect(campaign.reload.recipients_count).to eq(3)
        expect(pups.count { |pup| pup.reload.sms_invitation_sent_at.present? }).to eq(1)

        restore_sms_new
        travel(36.minutes)
        run_job
        expect(campaign.reload.recipients_count).to eq(3)
        expect(campaign.status).to eq('sent')
      end
    end

    describe 'giving up after the deadline (an open parent that never finishes)' do
      def reminder_with_parent(parent_status:, child_scheduled_at:, owner: intervention)
        parent = create(:pdp_sms_campaign, intervention: owner, kind: 'invitation', status: parent_status,
                                           accepted_count: 1, scheduled_at: 5.days.ago)
        create(:pdp_sms_campaign, intervention: owner, kind: 'scheduled_reminder', parent_campaign: parent,
                                  days_after: 3, status: 'scheduled', scheduled_at: child_scheduled_at)
      end

      it 'marks the reminder failed once it is more than 24h past scheduled_at and still stuck' do
        child = reminder_with_parent(parent_status: 'sending', child_scheduled_at: frozen_now - 25.hours)
        run_job(child)
        expect(child.reload.status).to eq('failed')
        expect(provider_calls).to be_empty
        expect(described_class).not_to have_been_enqueued.with(child.id)
      end

      it 'still reschedules a reminder that is stuck but within 24h of scheduled_at' do
        child = reminder_with_parent(parent_status: 'sending', child_scheduled_at: frozen_now - 1.hour)
        run_job(child)
        expect(child.reload.status).to eq('scheduled')
        expect(described_class).to have_been_enqueued.with(child.id).at(15.minutes.from_now)
      end

      it 'does not count a paused intervention toward the deadline: it keeps waiting past 24h' do
        paused = create(:intervention, :paused)
        child = reminder_with_parent(parent_status: 'sent', child_scheduled_at: frozen_now - 25.hours, owner: paused)
        run_job(child)
        expect(child.reload.status).to eq('scheduled')
        expect(described_class).to have_been_enqueued.with(child.id).at(15.minutes.from_now)
      end
    end

    describe 'a resumed run whose scope is now empty (crash after the last stamp, before close)' do
      it 'closes a campaign that already sent everyone as sent and anchors its reminder, not skipped' do
        reminder = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder',
                                             parent_campaign: campaign, days_after: 3, status: 'scheduled',
                                             scheduled_at: campaign.scheduled_at + 3.days)
        pups = Array.new(2) { |i| add_participant(i) }
        pups.each do |pup|
          create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, status: 'sent',
                                    sent_at: 5.minutes.ago)
        end
        PredefinedUserParameter.where(id: pups.map(&:id)).update_all(sms_invitation_sent_at: 5.minutes.ago)
        campaign.update_columns(status: 'sending', accepted_count: 2, recipients_count: 2)

        run_job

        expect(provider_calls).to be_empty
        expect(campaign.reload.status).to eq('sent')
        expect(campaign.sent_at).to be_within(1.second).of(frozen_now)
        expect(reminder.reload.scheduled_at).to be_within(1.second).of(frozen_now + 3.days)
      end

      it 'skips a campaign that reached nobody and sent nothing' do
        campaign.update_columns(status: 'sending', accepted_count: 0)
        run_job
        expect(provider_calls).to be_empty
        expect(campaign.reload.status).to eq('skipped')
      end
    end

    describe 'the delivery row is claimed before the SMS goes out' do
      it 'the delivery row already exists, pending, at the moment the provider is called' do
        add_participant(0)
        snapshots = []
        allow(twilio_messages).to receive(:create) do |**kwargs|
          snapshots << PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id).pluck(:status)
          provider_calls << kwargs
          fake_message
        end
        run_job
        expect(provider_calls.size).to eq(1)
        expect(snapshots).to eq([['pending']])
      end

      it 'a recipient who already has a sent row is skipped while a fresh recipient is sent' do
        done = add_participant(0)
        add_participant(1)
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: done, status: 'sent',
                                  sent_at: 2.hours.ago, created_at: 2.hours.ago, updated_at: 2.hours.ago)
        campaign.update!(status: 'sending')
        run_job
        expect(attempted_numbers).to eq([number_for(1)])
        expect(delivery_of(done).updated_at).to be_within(1.second).of(2.hours.ago)
        expect(PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id).count).to eq(2)
      end

      it 'a second run of the same campaign sends nobody again' do
        2.times { |i| add_participant(i) }
        run_job
        expect(provider_calls.size).to eq(2)
        PredefinedUserParameter.update_all(sms_invitation_sent_at: nil)
        campaign.update_columns(status: 'sending')
        run_job
        expect(provider_calls.size).to eq(2)
        expect(PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id).pluck(:status)).to all(eq('sent'))
      end

      it 'the job does not reload the campaign or its links once per recipient' do
        create(:pdp_campaign_sms_link, campaign: campaign)
        campaign.update!(body: "#{canary_body} ::canary_link::")
        selects = lambda do |count|
          run_campaign = create(:pdp_sms_campaign, intervention: create(:intervention, :published), kind: 'invitation',
                                                   scheduled_at: 1.hour.ago, body: "#{canary_body} ::canary_link::")
          create(:pdp_campaign_sms_link, campaign: run_campaign)
          count.times { |i| make_participant(run_campaign.intervention, index: i + 10) }
          queries = collect_queries { run_job(run_campaign) }
          expect(PredefinedParticipants::SmsDelivery.where(campaign_id: run_campaign.id).count).to eq(count)
          queries.select { |q| q.start_with?('SELECT') }
                 .grep(/FROM "(predefined_participants_sms_campaigns|sms_links)"/).size
        end
        expect(selects.call(5)).to eq(selects.call(1))
      end
    end

    describe 'stale pending rows are taken over, fresh ones are not' do
      def seed_row(pup, row_status: 'pending', created: 2.hours.ago, updated: 36.minutes.ago)
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, status: row_status,
                                  created_at: created, updated_at: updated)
      end

      before { campaign.update!(status: 'sending') }

      it 'a pending row last touched 36 minutes ago is taken over and sent' do
        pup = add_participant(0)
        seed_row(pup)
        run_job
        expect(attempted_numbers).to eq([number_for(0)])
        expect(delivery_of(pup).status).to eq('sent')
        expect(PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id).count).to eq(1)
      end

      it 'a pending row last touched 10 minutes ago is left alone while a witness recipient is sent' do
        pup = add_participant(0)
        add_participant(1)
        seed_row(pup, updated: 10.minutes.ago)
        run_job
        expect(attempted_numbers).to eq([number_for(1)])
        expect(delivery_of(pup).status).to eq('pending')
        expect(delivery_of(pup).updated_at).to be_within(1.second).of(10.minutes.ago)
      end

      it 'the threshold keys on updated_at: an old created_at with a fresh updated_at is not taken over' do
        pup = add_participant(0)
        add_participant(1)
        seed_row(pup, created: 3.hours.ago, updated: 5.minutes.ago)
        run_job
        expect(attempted_numbers).to eq([number_for(1)])
        expect(delivery_of(pup).status).to eq('pending')
      end

      it 'an old failed row is never retried by the same campaign while a witness recipient is sent' do
        pup = add_participant(0)
        add_participant(1)
        seed_row(pup, row_status: 'failed', updated: 3.hours.ago)
        run_job
        expect(attempted_numbers).to eq([number_for(1)])
        expect(delivery_of(pup).status).to eq('failed')
      end
    end

    describe 'takeover transfers ownership atomically with a compare-and-swap' do
      it 'after a run took a stale row over and died, a run started right after cannot take it again' do
        pup = add_participant(0)
        campaign.update!(status: 'sending')
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, status: 'pending',
                                  created_at: 2.hours.ago, updated_at: 36.minutes.ago)

        raise_on_sms_new(1, ApplicationJob::JobTimeoutError)
        expect { run_job }.to raise_error(ApplicationJob::JobTimeoutError)
        owned = delivery_of(pup)
        expect(owned.status).to eq('pending')
        expect(owned.updated_at).to be_within(1.second).of(frozen_now)

        restore_sms_new
        run_job
        expect(provider_calls).to be_empty
        expect(delivery_of(pup).status).to eq('pending')

        campaign.update_columns(status: 'sending')
        travel(36.minutes)
        run_job
        expect(attempted_numbers).to eq([number_for(0)])
        expect(delivery_of(pup).status).to eq('sent')
      end
    end

    describe 'a delivery the provider already accepted is never sent a second time' do
      it 'a worker killed while marking an accepted message sent does not re-send it on the retry' do
        add_participant(0)
        add_participant(1)
        calls = 0
        allow_any_instance_of(described_class).to receive(:mark_sent).and_wrap_original do |orig, *args|
          calls += 1
          raise ApplicationJob::JobTimeoutError, 'injected while marking sent' if calls == 1

          orig.call(*args)
        end

        expect { run_job }.to raise_error(ApplicationJob::JobTimeoutError)
        accepted = attempted_numbers.first
        expect(attempted_numbers).to eq([accepted])

        allow_any_instance_of(described_class).to receive(:mark_sent).and_call_original
        travel(1.hour)
        run_job

        expect(attempted_numbers.count(accepted)).to eq(1)
        expect(attempted_numbers.uniq.size).to eq(2)
        expect(campaign.reload).to have_attributes(status: 'sent', accepted_count: 2)
      end

      it 'a provider timeout raised after the message was accepted still leaves the recipient sent exactly once' do
        pup = add_participant(0)
        add_participant(1)
        allow_any_instance_of(Communication::Sms).to receive(:send_message).and_wrap_original do |orig, *args|
          receiver = orig.receiver
          orig.call(*args)
          next unless receiver.sms.phone == number_for(0)

          receiver.errors << 'injected'
          receiver.instance_variable_set(:@provider_error_code, described_class::TIMEOUT_CODE)
        end

        expect { run_job }.to raise_error(ApplicationJob::JobTimeoutError)
        expect(delivery_of(pup).status).to eq('pending')

        allow_any_instance_of(Communication::Sms).to receive(:send_message).and_call_original
        travel(1.hour)
        run_job

        expect(attempted_numbers.count(number_for(0))).to eq(1)
        expect(delivery_of(pup).status).to eq('sent')
      end
    end

    describe 'provider errors are read, not swallowed' do
      it 'a rejected recipient ends failed, unstamped and counted; the campaign ends sent because the other is sent' do
        bad = add_participant(0)
        good = add_participant(1)
        fail_provider_for(number_for(0))
        run_job
        failed = delivery_of(bad)
        expect(failed.status).to eq('failed')
        expect(failed.error_code).to be_present
        expect(failed.message.status).to eq('error')
        expect(bad.reload.sms_invitation_sent_at).to be_nil
        expect(delivery_of(good).status).to eq('sent')
        expect(good.reload.sms_invitation_sent_at).to be_present
        expect(campaign.reload).to have_attributes(status: 'sent', failed_count: 1, accepted_count: 1)
        expect(campaign.sent_at).to be_within(1.second).of(frozen_now)
      end

      it 'when every recipient is rejected the campaign is failed, never sent with zero accepted' do
        pups = Array.new(2) { |i| add_participant(i) }
        fail_provider_for(number_for(0), number_for(1))
        run_job
        expect(campaign.reload).to have_attributes(status: 'failed', failed_count: 2, accepted_count: 0)
        expect(pups.map { |pup| delivery_of(pup).status }).to all(eq('failed'))
        expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_nil)
      end

      it 'the same recipients with an accepting provider are sent and stamped' do
        pups = Array.new(2) { |i| add_participant(i) }
        run_job
        expect(campaign.reload).to have_attributes(status: 'sent', failed_count: 0, accepted_count: 2)
        expect(pups.map { |pup| delivery_of(pup).status }).to all(eq('sent'))
        expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_present)
      end

      it 'a body above the Twilio limit of 1600 characters is rejected visibly, not silently' do
        campaign.update!(body: 'A' * 1601)
        pup = add_participant(0)
        allow(twilio_messages).to receive(:create) do |**kwargs|
          provider_calls << kwargs
          raise provider_error(kwargs[:to]) if kwargs[:body].length > 1600

          fake_message
        end
        run_job
        expect(provider_calls.size).to eq(1)
        expect(delivery_of(pup).status).to eq('failed')
        expect(campaign.reload).to have_attributes(status: 'failed', failed_count: 1, accepted_count: 0)
      end
    end

    describe 'one recipient failing does not abort the batch' do
      it 'an exception while rendering one recipient leaves the other two sent and closes the campaign' do
        pups = Array.new(3) { |i| add_participant(i) }
        bad = pups[1]
        allow(V1::PredefinedParticipants::SmsCampaigns::RenderBody).to receive(:call).and_wrap_original do |original, *args|
          raise StandardError, 'render failure' if args[1].id == bad.id

          original.call(*args)
        end
        expect { run_job }.not_to raise_error
        expect(attempted_numbers).to contain_exactly(number_for(0), number_for(2))
        expect(delivery_of(pups[0]).status).to eq('sent')
        expect(delivery_of(pups[2]).status).to eq('sent')
        expect(bad.reload.sms_invitation_sent_at).to be_nil
        expect(campaign.reload.status).to be_in(%w[sent failed])
      end

      it 'an exception while sending one recipient leaves the other two sent and the failed one counted' do
        pups = Array.new(3) { |i| add_participant(i) }
        raise_on_sms_new(1, StandardError)
        expect { run_job }.not_to raise_error
        expect(provider_calls.size).to eq(2)
        expect(pups.map { |pup| delivery_of(pup)&.status }).to match_array(%w[sent sent failed])
        expect(campaign.reload).to have_attributes(status: 'sent', failed_count: 1, accepted_count: 2)
      end
    end

    describe 'JobTimeoutError passes through every per-recipient rescue' do
      let(:render_body) { V1::PredefinedParticipants::SmsCampaigns::RenderBody }

      it 'a timeout raised while claiming a recipient leaves the job and is not recorded as a failed recipient' do
        3.times { |i| add_participant(i) }
        allow(render_body).to receive(:call).and_raise(ApplicationJob::JobTimeoutError, 'execution expired')
        expect { run_job }.to raise_error(ApplicationJob::JobTimeoutError)
        expect(render_body).to have_received(:call).once
        expect(PredefinedParticipants::SmsDelivery.where(status: 'failed')).to be_empty
        expect(campaign.reload).to have_attributes(status: 'sending', failed_count: 0)
        expect(provider_calls).to be_empty
      end

      it 'the same claim-phase injection with a plain StandardError is isolated per recipient' do
        3.times { |i| add_participant(i) }
        allow(render_body).to receive(:call).and_raise(StandardError, 'render failure')
        expect { run_job }.not_to raise_error
        expect(render_body).to have_received(:call).exactly(3).times
        expect(campaign.reload.status).to be_in(%w[sent failed])
      end

      it 'a timeout raised while sending leaves the job, keeps the row pending and stops the loop' do
        pups = Array.new(3) { |i| add_participant(i) }
        raise_on_sms_new(1, ApplicationJob::JobTimeoutError)
        expect { run_job }.to raise_error(ApplicationJob::JobTimeoutError)
        expect(Communication::Sms).to have_received(:new).once
        rows = PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id)
        expect(rows.pluck(:status)).to eq(['pending'])
        expect(rows.where(status: 'failed')).to be_empty
        expect(campaign.reload).to have_attributes(status: 'sending', failed_count: 0, accepted_count: 0)
        expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_nil)
        expect(provider_calls).to be_empty
      end

      it 'the same send-phase injection with a plain StandardError fails one recipient and finishes' do
        3.times { |i| add_participant(i) }
        raise_on_sms_new(1, StandardError)
        expect { run_job }.not_to raise_error
        expect(campaign.reload.status).to eq('sent')
        expect(provider_calls.size).to eq(2)
      end

      it 'through the queue the timeout is retried, and the retry finishes every recipient exactly once' do
        3.times { |i| add_participant(i) }
        raise_on_sms_new(2, ApplicationJob::JobTimeoutError)
        described_class.perform_now(campaign.id)
        expect(described_class).to have_been_enqueued.with(campaign.id)
        expect(PredefinedParticipants::SmsDelivery.where(status: 'failed')).to be_empty

        restore_sms_new
        travel(1.hour)
        described_class.perform_now(campaign.id)
        expect(provider_calls.size).to eq(3)
        expect(attempted_numbers.uniq.size).to eq(3)
        expect(campaign.reload).to have_attributes(status: 'sent', accepted_count: 3, failed_count: 0)
      end
    end

    describe 'delivery sent and participant stamped in one transaction' do
      def block_writes(table, condition)
        ActiveRecord::Base.lease_connection.execute(
          "ALTER TABLE #{table} ADD CONSTRAINT spec_block_writes CHECK (#{condition}) NOT VALID"
        )
      end

      it 'without interference both the sent row and the stamp are written' do
        pup = add_participant(0)
        run_job
        expect(delivery_of(pup).status).to eq('sent')
        expect(pup.reload.sms_invitation_sent_at).to be_present
        expect(campaign.reload.accepted_count).to eq(1)
      end

      it 'when stamping the participant fails the delivery is not left as sent either' do
        pup = add_participant(0)
        block_writes('predefined_user_parameters', 'sms_invitation_sent_at IS NULL')
        run_job
        expect(provider_calls.size).to eq(1)
        expect(delivery_of(pup)).to be_present
        expect(delivery_of(pup).status).not_to eq('sent')
        expect(pup.reload.sms_invitation_sent_at).to be_nil
        expect(campaign.reload.accepted_count).to eq(0)
      end

      it 'when writing the sent row fails the participant is not stamped' do
        pup = add_participant(0)
        block_writes('predefined_participants_sms_deliveries', "status <> 'sent'")
        run_job
        expect(provider_calls.size).to eq(1)
        expect(delivery_of(pup)).to be_present
        expect(delivery_of(pup).status).not_to eq('sent')
        expect(pup.reload.sms_invitation_sent_at).to be_nil
        expect(campaign.reload.accepted_count).to eq(0)
      end

      context 'with a manual reminder' do
        let(:kind) { 'manual_reminder' }

        it 'when stamping last_reminder_sent_at fails the delivery is not left as sent' do
          pup = add_participant(0)
          block_writes('predefined_user_parameters', 'last_reminder_sent_at IS NULL')
          run_job
          expect(delivery_of(pup)).to be_present
          expect(delivery_of(pup).status).not_to eq('sent')
          expect(pup.reload.last_reminder_sent_at).to be_nil
          expect(campaign.reload.accepted_count).to eq(0)
        end
      end
    end

    describe 'counters stay consistent and sent rows are never flipped' do
      it 'a run over an already sent row and an already failed row changes neither and counts only the new failure' do
        sent_pup = add_participant(0)
        failed_pup = add_participant(1)
        new_pup = add_participant(2)
        campaign.update!(status: 'sending', accepted_count: 1, failed_count: 1)
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: sent_pup, status: 'sent',
                                  created_at: 3.hours.ago, updated_at: 3.hours.ago)
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: failed_pup, status: 'failed',
                                  error_code: 'Twilio::REST::RestError', created_at: 3.hours.ago, updated_at: 3.hours.ago)
        fail_provider_for(number_for(2))
        run_job
        expect(attempted_numbers).to eq([number_for(2)])
        expect(delivery_of(sent_pup).status).to eq('sent')
        expect(delivery_of(failed_pup).status).to eq('failed')
        expect(delivery_of(new_pup).status).to eq('failed')
        expect(campaign.reload).to have_attributes(failed_count: 2, accepted_count: 1)
      end

      it 'failed_count equals the number of failed rows after a second run over the same failed recipient' do
        add_participant(0)
        add_participant(1)
        fail_provider_for(number_for(0))
        run_job
        expect(campaign.reload.failed_count).to eq(1)

        campaign.update_columns(status: 'sending')
        PredefinedUserParameter.update_all(sms_invitation_sent_at: nil)
        run_job
        failed_rows = PredefinedParticipants::SmsDelivery.where(campaign_id: campaign.id, status: 'failed').count
        expect(failed_rows).to eq(1)
        expect(campaign.reload.failed_count).to eq(failed_rows)
        expect(attempted_numbers).to contain_exactly(number_for(0), number_for(1))
      end

      it 'a stale pending row taken over whose send is rejected is counted exactly once' do
        pup = add_participant(0)
        campaign.update!(status: 'sending')
        create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, status: 'pending',
                                  created_at: 2.hours.ago, updated_at: 36.minutes.ago)
        fail_provider_for(number_for(0))
        run_job
        expect(delivery_of(pup).status).to eq('failed')
        expect(campaign.reload.failed_count).to eq(1)
      end

      it 'a sent row stays sent and is counted once in accepted_count' do
        pup = add_participant(0)
        run_job
        expect(delivery_of(pup).status).to eq('sent')
        expect(campaign.reload).to have_attributes(accepted_count: 1, failed_count: 0)
      end
    end

    describe 'closing the campaign' do
      %w[invitation manual_reminder scheduled_reminder].each do |campaign_kind|
        context "with a #{campaign_kind} campaign" do
          let(:kind) { campaign_kind }

          it "closes a #{campaign_kind} campaign without failures as sent with sent_at set" do
            2.times { |i| add_participant(i) }
            run_job
            expect(campaign.reload).to have_attributes(status: 'sent', failed_count: 0)
            expect(campaign.sent_at).to be_within(1.second).of(frozen_now)
          end

          it "closes a #{campaign_kind} campaign with one failure among accepted messages as sent with sent_at set" do
            2.times { |i| add_participant(i) }
            fail_provider_for(number_for(0))
            run_job
            expect(campaign.reload).to have_attributes(status: 'sent', failed_count: 1)
            expect(campaign.sent_at).to be_within(1.second).of(frozen_now)
          end
        end
      end
    end

    describe 'anchoring the scheduled reminder to the real send time' do
      let(:campaign_attrs) { { scheduled_at: 2.days.ago } }

      def reminder_for(parent, **attrs)
        create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: parent,
                                  days_after: 3, status: 'scheduled', scheduled_at: parent.scheduled_at + 3.days, **attrs)
      end

      it 'moves the reminder to days_after days past the actual sent_at, not the planned scheduled_at' do
        reminder = reminder_for(campaign)
        add_participant(0)
        run_job
        expect(campaign.reload.sent_at).to be_within(1.second).of(frozen_now)
        expect(reminder.reload.scheduled_at).to be_within(1.second).of(frozen_now + 3.days)
      end

      it 'keeps the time of day of the send in the author time zone' do
        researcher = create(:user, :researcher, time_zone: 'America/New_York')
        campaign.update!(author: researcher)
        reminder = reminder_for(campaign, author: researcher)
        add_participant(0)
        run_job
        local = reminder.reload.scheduled_at.in_time_zone('America/New_York')
        expect(local.to_date).to eq(Date.new(2026, 11, 2))
        expect(local.strftime('%H:%M')).to eq(frozen_now.in_time_zone('America/New_York').strftime('%H:%M'))
      end

      it 'leaves a reminder that is no longer scheduled untouched' do
        reminder = reminder_for(campaign, status: 'cancelled')
        planned = reminder.scheduled_at
        add_participant(0)
        run_job
        expect(reminder.reload.scheduled_at).to be_within(1.second).of(planned)
      end

      it 'does not anchor the reminder when the campaign closes without a single accepted message' do
        reminder = reminder_for(campaign)
        planned = reminder.scheduled_at
        add_participant(0)
        fail_provider_for(number_for(0))
        run_job
        expect(campaign.reload.status).to eq('failed')
        expect(reminder.reload.scheduled_at).to be_within(1.second).of(planned)
      end
    end

    describe 'stamp writes the right column and enqueues nothing' do
      let(:volatile) { %w[updated_at sms_invitation_sent_at last_reminder_sent_at] }

      it 'an invitation stamps sms_invitation_sent_at only' do
        pup = add_participant(0)
        before = pup.reload.attributes.except(*volatile)
        run_job
        pup.reload
        expect(delivery_of(pup).status).to eq('sent')
        expect(pup.sms_invitation_sent_at).to be_within(1.second).of(frozen_now)
        expect(pup.last_reminder_sent_at).to be_nil
        expect(pup.attributes.except(*volatile)).to eq(before)
      end

      %w[manual_reminder scheduled_reminder].each do |reminder_kind|
        context "with a #{reminder_kind} campaign" do
          let(:kind) { reminder_kind }

          it "a #{reminder_kind} stamps last_reminder_sent_at and leaves sms_invitation_sent_at as it was" do
            pup = add_participant(0)
            invited_at = pup.reload.sms_invitation_sent_at
            before = pup.attributes.except(*volatile)
            run_job
            pup.reload
            expect(delivery_of(pup).status).to eq('sent')
            expect(invited_at).to be_present
            expect(pup.last_reminder_sent_at).to be_within(1.second).of(frozen_now)
            expect(pup.sms_invitation_sent_at).to be_within(1.second).of(invited_at)
            expect(pup.attributes.except(*volatile)).to eq(before)
          end

          it "a #{reminder_kind} run enqueues no job of any class" do
            pup = add_participant(0)
            enqueued = record_enqueues { run_job }
            expect(delivery_of(pup).status).to eq('sent')
            expect(enqueued).to be_empty
          end
        end
      end

      it 'an invitation run without a child reminder enqueues no job of any class' do
        pup = add_participant(0)
        enqueued = record_enqueues { run_job }
        expect(delivery_of(pup).status).to eq('sent')
        expect(enqueued).to be_empty
      end
    end

    describe 'no phone number or message body outside the encrypted columns' do
      let(:leaks) { [number_for(0), '2015550123', canary_body] }

      it 'error_code of a rejected delivery is the provider error class or code and nothing else' do
        pup = add_participant(0)
        fail_provider_for(number_for(0))
        run_job
        code = delivery_of(pup).error_code
        expect(delivery_of(pup).status).to eq('failed')
        expect(code).to match(/\A(Twilio::REST::RestError|TWILIO_21211)\z/)
        leaks.each { |leak| expect(code).not_to include(leak) }
      end

      it 'error_code of a delivery that failed on an unexpected exception carries no number or body' do
        pup = add_participant(0)
        allow(Communication::Sms).to receive(:new).and_raise(StandardError, "boom #{number_for(0)} #{canary_body}")
        run_job
        expect(delivery_of(pup).status).to eq('failed')
        leaks.each { |leak| expect(delivery_of(pup).error_code.to_s).not_to include(leak) }
      end

      it 'the raw log of a failing run contains neither the number nor the body' do
        pup = add_participant(0)
        fail_provider_for(number_for(0))
        log = capture_log { run_job }
        expect(delivery_of(pup).status).to eq('failed')
        expect(log).to include('predefined_participants_sms_deliveries')
        leaks.each { |leak| expect(log).not_to include(leak) }
      end
    end

    describe 'the job argument is campaign.id only' do
      it 'perform takes exactly one argument' do
        expect(described_class.instance_method(:perform).arity).to eq(1)
      end

      it 'a job enqueued with the campaign id carries nothing else and reads number and body itself' do
        pup = add_participant(0)
        described_class.perform_later(campaign.id)
        entry = campaign_jobs.last
        expect(entry[:args]).to eq([campaign.id])
        expect(entry.to_json).not_to include(number_for(0))
        expect(entry.to_json).not_to include(canary_body)

        ActiveJob::Base.queue_adapter.enqueued_jobs.clear
        ActiveJob::Base.execute(entry)
        expect(attempted_numbers).to eq([number_for(0)])
        expect(provider_calls.first[:body]).to start_with(canary_body)
        expect(delivery_of(pup).status).to eq('sent')
      end

      it 'the job re-enqueues itself with the campaign id only' do
        add_participant(0)
        future = create(:pdp_sms_campaign, intervention: create(:intervention, :published), kind: 'invitation',
                                           scheduled_at: 2.hours.from_now)
        run_job(future)
        entries = campaign_jobs
        expect(entries).not_to be_empty
        expect(entries.pluck(:args)).to all(eq([future.id]))
      end
    end

    describe 'queue is sms_plans' do
      it 'the job class is routed to sms_plans' do
        expect(described_class.new(SecureRandom.uuid).queue_name).to eq('sms_plans')
      end

      it 'sms_plans is a queue Sidekiq actually listens on' do
        config = YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result, permitted_classes: [Symbol])
        names = config.fetch(:queues).map { |queue| Array(queue).first.to_s }
        expect(names).to include('sms_plans')
      end

      it 'an enqueued campaign job lands on sms_plans and, once executed from there, sends' do
        pup = add_participant(0)
        described_class.perform_later(campaign.id)
        entry = campaign_jobs.last
        expect(entry[:queue]).to eq('sms_plans')
        ActiveJob::Base.execute(entry)
        expect(delivery_of(pup).status).to eq('sent')
      end

      it 'the job re-enqueues itself on sms_plans' do
        future = create(:pdp_sms_campaign, intervention: create(:intervention, :published), kind: 'invitation',
                                           scheduled_at: 2.hours.from_now)
        run_job(future)
        entries = campaign_jobs
        expect(entries).not_to be_empty
        expect(entries.pluck(:queue)).to all(eq('sms_plans'))
      end
    end
  end

  context 'with a recording Twilio client' do
    include PredefinedParticipantSmsHelpers

    # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration, RSpec/InstanceVariable
    class TddProviderRecorder
      attr_reader :calls

      def initialize
        @calls = []
        @hook = nil
      end

      def messages = self

      def on_create(&block)
        @hook = block
      end

      def create(**kwargs)
        @calls << kwargs
        @hook&.call(kwargs)
        Struct.new(:sid).new('SMTDD')
      end

      def numbers = @calls.pluck(:to)
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration, RSpec/InstanceVariable

    let(:intervention) { create(:intervention, :published) }
    let(:provider) { TddProviderRecorder.new }
    let(:render_class) { V1::PredefinedParticipants::SmsCampaigns::RenderBody }

    before do
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      allow(Twilio::REST::Client).to receive(:new).and_return(provider)
      travel_to(frozen_now)
      stub_web_url
    end

    # rubocop:disable Metrics/ParameterLists
    def prepare(kind: 'invitation', count: 3, status: 'scheduled', offset: 0, owner: intervention, **attrs)
      invited_at = kind == 'invitation' ? nil : frozen_now - 3.days
      pups = Array.new(count) { |i| make_participant(owner, index: offset + i, invited_at: invited_at) }
      campaign =
        if kind == 'scheduled_reminder'
          parent = create(:pdp_sms_campaign, intervention: owner, kind: 'invitation', status: 'sent', accepted_count: count,
                                             recipients_count: count, sent_at: frozen_now - 3.days)
          pups.each do |pup|
            create(:pdp_sms_delivery, campaign: parent, predefined_user_parameter: pup, status: 'sent', sent_at: frozen_now - 3.days)
          end
          create(:pdp_sms_campaign, intervention: owner, kind: kind, status: status, parent_campaign: parent, days_after: 3,
                                    scheduled_at: frozen_now - 1.minute, **attrs)
        else
          create(:pdp_sms_campaign, intervention: owner, kind: kind, status: status, scheduled_at: frozen_now - 1.minute, **attrs)
        end
      [campaign, pups]
    end
    # rubocop:enable Metrics/ParameterLists

    def phone_of(pup) = pup.user.phone.full_number

    def campaign_jobs
      ActiveJob::Base.queue_adapter.enqueued_jobs.select { |entry| entry[:job] == described_class }
    end

    def run_job(campaign) = described_class.perform_now(campaign.id)

    def run_directly(campaign) = described_class.new.perform(campaign.id)

    def delivery_of(campaign, pup)
      PredefinedParticipants::SmsDelivery.find_by(campaign_id: campaign.id, predefined_user_parameter_id: pup.id)
    end

    def delivery_of!(campaign, pup)
      row = delivery_of(campaign, pup)
      expect(row).to be_present, "no delivery row was claimed for #{pup.id}"
      row
    end

    def expected_body(pup) = "#{canary_body}\n#{web_url}/usr/#{pup.slug}"

    def seed_row(campaign, pup, status:, updated_at: frozen_now, **attrs)
      row = create(:pdp_sms_delivery, campaign: campaign, predefined_user_parameter: pup, status: status,
                                      body: 'pre-existing row body', **attrs)
      row.update_columns(updated_at: updated_at)
      row
    end

    def rest_error(to, body, code: 21_211)
      response = Struct.new(:status_code, :body).new(400, { 'code' => code, 'message' => "The 'To' number #{to} is not valid. #{body}" })
      Twilio::REST::RestError.new("Unable to create record for #{to}: #{body}", response)
    end

    def fail_provider_for(numbers)
      provider.on_create do |kwargs|
        raise rest_error(kwargs[:to], kwargs[:body]) if numbers.include?(kwargs[:to])
      end
    end

    def install_raising_trigger(name, table, condition)
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        CREATE OR REPLACE FUNCTION #{name}() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'tdd injected failure'; END; $$ LANGUAGE plpgsql;
        CREATE TRIGGER #{name} BEFORE UPDATE ON #{table} FOR EACH ROW WHEN (#{condition}) EXECUTE FUNCTION #{name}();
      SQL
    end

    def inject(point, error:, nth: nil, victim: nil, state: { on: true })
      count = 0
      decide = lambda do |ctx|
        next false unless state[:on]

        next (count += 1) == nth if nth

        ctx == (point == :render ? victim.id : phone_of(victim))
      end
      case point
      when :render
        allow(render_class).to receive(:call).and_wrap_original do |orig, camp, pup, links|
          raise error, 'injected' if decide.call(pup.id)

          orig.call(camp, pup, links)
        end
      when :sms_new
        allow(Communication::Sms).to receive(:new).and_wrap_original do |orig, message, **options|
          raise error, 'injected' if decide.call(message.phone)

          orig.call(message, **options)
        end
      when :send_message
        allow_any_instance_of(Communication::Sms).to receive(:send_message).and_wrap_original do |orig, *args|
          raise error, 'injected' if decide.call(orig.receiver.sms.phone)

          orig.call(*args)
        end
      end
    end

    INJECTION_POINTS = %i[render sms_new send_message].freeze # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration

    describe 'campaign in a status other than scheduled or sending is a no-op' do
      %w[sent failed cancelled skipped].each do |status|
        it "a #{status} campaign sends nothing, creates nothing and keeps its status" do
          campaign, pups = prepare(status: status)
          messages_before = Message.count

          expect { run_job(campaign) }.not_to(change { [Message.count, PredefinedParticipants::SmsDelivery.count] })

          expect(provider.calls).to be_empty
          expect(Message.count).to eq(messages_before)
          expect(campaign.reload.status).to eq(status)
          expect(campaign.recipients_count).to be_nil
          expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_nil)
          expect(campaign_jobs).to be_empty
        end
      end

      %w[scheduled sending].each do |status|
        it "a #{status} campaign on the same set-up is processed (positive control for the no-op examples)" do
          campaign, pups = prepare(status: status)

          run_job(campaign)

          expect(provider.numbers).to match_array(pups.map { |pup| phone_of(pup) })
          expect(campaign.reload.status).to eq('sent')
        end
      end
    end

    describe 'an intervention that is not published at fire time skips the campaign' do
      context 'with a paused intervention' do
        let(:intervention) { create(:intervention, :paused) }

        it 'reschedules the campaign, sends nothing and stamps nobody, so a re-publish can still send it' do
          campaign, pups = prepare

          run_job(campaign)

          expect(campaign.reload.status).to eq('scheduled')
          expect(provider.calls).to be_empty
          expect(campaign.deliveries).to be_empty
          expect(campaign.scheduled_at).to eq(frozen_now - 1.minute)
          expect(described_class).to have_been_enqueued.with(campaign.id).at(15.minutes.from_now)
          expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_nil)
        end
      end

      { 'closed' => [:closed], 'archived' => [:archived], 'draft' => [] }.each do |name, traits|
        context "with a #{name} intervention" do
          let(:intervention) { create(:intervention, *traits) }

          it "ends skipped, sends nothing and is never rescheduled (#{name})" do
            campaign, pups = prepare

            run_job(campaign)

            expect(campaign.reload.status).to eq('skipped')
            expect(provider.calls).to be_empty
            expect(campaign.deliveries).to be_empty
            expect(campaign.scheduled_at).to eq(frozen_now - 1.minute)
            expect(campaign_jobs).to be_empty
            expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_nil)
          end
        end
      end

      it 'the same campaign on a published intervention sends and is not skipped' do
        campaign, pups = prepare

        run_job(campaign)

        expect(provider.numbers).to match_array(pups.map { |pup| phone_of(pup) })
        expect(campaign.reload.status).not_to eq('skipped')
      end

      it 'the enqueue recorder sees an enqueue made on the same adapter' do
        campaign, = prepare
        described_class.perform_later(campaign.id)

        expect(campaign_jobs.size).to eq(1)
      end
    end

    describe 'recipients_count is written on the first run only' do
      it 'the first run stores the size of the recipient set' do
        campaign, pups = prepare(count: 3)
        expect(campaign.recipients_count).to be_nil

        run_job(campaign)

        expect(campaign.reload.recipients_count).to eq(pups.size)
      end

      it 'a run that finds recipients_count already set does not overwrite it' do
        campaign, = prepare(count: 3, status: 'sending', recipients_count: 99)

        run_job(campaign)

        expect(campaign.reload.recipients_count).to eq(99)
        expect(provider.calls.size).to eq(3)
      end

      it 'a resumed run keeps the original size although its own scope has narrowed' do
        campaign, = prepare(count: 3)
        state = { on: true }
        inject(:render, error: ApplicationJob::JobTimeoutError, nth: 2, state: state)
        expect { run_directly(campaign) }.to raise_error(ApplicationJob::JobTimeoutError)
        expect(campaign.reload.recipients_count).to eq(3)

        state[:on] = false
        travel_to(frozen_now + 36.minutes)
        run_directly(campaign)

        expect(campaign.reload.recipients_count).to eq(3)
        expect(provider.calls.size).to eq(3)
      end
    end

    describe 'the delivery row is claimed before the SMS goes out' do
      it 'a pending delivery row for the recipient already exists while the provider is being called' do
        campaign, pups = prepare(count: 3)
        states = {}
        provider.on_create do |kwargs|
          row = PredefinedParticipants::SmsDelivery.find_by(campaign_id: campaign.id, body: kwargs[:body])
          states[kwargs[:to]] = row&.status
        end

        run_job(campaign)

        expect(states.keys).to match_array(pups.map { |pup| phone_of(pup) })
        expect(states.values.uniq).to eq(['pending'])
        expect(campaign.deliveries.pluck(:status).uniq).to eq(['sent'])
      end

      it 'the stored delivery body is exactly the text handed to the provider' do
        campaign, pups = prepare(count: 2)

        run_job(campaign)

        pups.each do |pup|
          call = provider.calls.find { |c| c[:to] == phone_of(pup) }
          expect(call).to be_present
          expect(call[:body]).to eq(expected_body(pup))
          expect(delivery_of!(campaign, pup).body).to eq(call[:body])
        end
      end

      it 'a recipient that already has a sent row is not messaged again, the others are' do
        campaign, pups = prepare(count: 3, status: 'sending')
        seed_row(campaign, pups.first, status: 'sent', sent_at: frozen_now - 1.hour)

        run_job(campaign)

        expect(provider.numbers).to match_array(pups.drop(1).map { |pup| phone_of(pup) })
        expect(campaign.deliveries.count).to eq(3)
        expect(delivery_of(campaign, pups.first).status).to eq('sent')
      end

      it 'a recipient whose row is already failed is not retried by the same campaign' do
        campaign, pups = prepare(count: 2, status: 'sending')
        seed_row(campaign, pups.first, status: 'failed', error_code: 'X')

        run_job(campaign)

        expect(provider.numbers).to eq([phone_of(pups.last)])
        expect(delivery_of(campaign, pups.first).status).to eq('failed')
      end

      it 'a second run of an already processed campaign sends nothing more' do
        campaign, pups = prepare(count: 2)
        run_job(campaign)
        expect(provider.calls.size).to eq(2)
        campaign.update_columns(status: 'sending')

        run_job(campaign)

        expect(provider.calls.size).to eq(2)
        expect(pups.map { |pup| delivery_of(campaign, pup).status }).to all(eq('sent'))
      end

      it 'a recipient without any row is messaged and gets exactly one row' do
        campaign, pups = prepare(count: 2, status: 'sending')

        run_job(campaign)

        expect(provider.numbers).to match_array(pups.map { |pup| phone_of(pup) })
        expect(campaign.deliveries.count).to eq(2)
      end
    end

    describe 'a stale pending row is taken over, a fresh one is not' do
      it 'a pending row last touched 36 minutes ago is taken over and the recipient messaged once' do
        campaign, pups = prepare(count: 2, status: 'sending')
        seed_row(campaign, pups.first, status: 'pending', updated_at: frozen_now - 36.minutes)

        run_job(campaign)

        expect(provider.numbers.tally[phone_of(pups.first)]).to eq(1)
        expect(delivery_of(campaign, pups.first).status).to eq('sent')
        expect(campaign.deliveries.count).to eq(2)
        expect(campaign.reload.accepted_count).to eq(2)
      end

      it 'a pending row last touched 34 minutes ago is left alone' do
        campaign, pups = prepare(count: 2, status: 'sending')
        row = seed_row(campaign, pups.first, status: 'pending', updated_at: frozen_now - 34.minutes)

        run_job(campaign)

        expect(provider.numbers).to eq([phone_of(pups.last)])
        expect(row.reload.status).to eq('pending')
        expect(row.updated_at).to eq(frozen_now - 34.minutes)
      end

      it 'the threshold keys on updated_at: an old created_at with a recent update is not reclaimed' do
        campaign, pups = prepare(count: 2, status: 'sending')
        row = seed_row(campaign, pups.first, status: 'pending', updated_at: frozen_now - 1.minute)
        row.update_columns(created_at: frozen_now - 3.hours)

        run_job(campaign)

        expect(provider.numbers).to eq([phone_of(pups.last)])
        expect(row.reload.status).to eq('pending')
      end

      it 'the stale row is a recipient only for the run after the threshold has passed' do
        campaign, pups = prepare(count: 1, status: 'sending')
        seed_row(campaign, pups.first, status: 'pending', updated_at: frozen_now - 10.minutes)
        run_job(campaign)
        expect(provider.calls).to be_empty

        travel_to(frozen_now + 26.minutes)
        campaign.update_columns(status: 'sending')
        run_job(campaign)

        expect(provider.numbers).to eq([phone_of(pups.first)])
      end
    end

    describe 'taking over a stale row is atomic' do
      it 'a second run started while the first holds a taken-over row does not message that recipient again' do
        campaign, pups = prepare(count: 1, status: 'sending')
        seed_row(campaign, pups.first, status: 'pending', updated_at: frozen_now - 36.minutes)
        nested = false
        provider.on_create do
          next if nested

          nested = true
          described_class.perform_now(campaign.id)
        end

        run_job(campaign)

        expect(nested).to be(true)
        expect(provider.numbers).to eq([phone_of(pups.first)])
        expect(delivery_of(campaign, pups.first).status).to eq('sent')
      end

      it 'two interleaved runs over several recipients message every number exactly once' do
        campaign, pups = prepare(count: 3, status: 'sending')
        seed_row(campaign, pups.first, status: 'pending', updated_at: frozen_now - 36.minutes)
        nested = false
        provider.on_create do
          next if nested

          nested = true
          described_class.perform_now(campaign.id)
        end

        run_job(campaign)

        expect(provider.numbers).to match_array(pups.map { |pup| phone_of(pup) })
        expect(campaign.reload.accepted_count).to eq(3)
        expect(campaign.deliveries.count).to eq(3)
      end

      it 'a fresh claim made by the first run is not taken by the interleaved second run' do
        campaign, pups = prepare(count: 1, status: 'sending')
        nested = false
        provider.on_create do
          next if nested

          nested = true
          described_class.perform_now(campaign.id)
        end

        run_job(campaign)

        expect(provider.numbers).to eq([phone_of(pups.first)])
      end
    end

    describe 'a provider error is read from the outcome of send_message' do
      it 'the failed recipient gets a failed delivery, is not stamped and the campaign still ends sent' do
        campaign, pups = prepare(count: 3)
        victim = pups.first
        fail_provider_for([phone_of(victim)])

        expect { run_job(campaign) }.not_to raise_error

        row = delivery_of!(campaign, victim)
        expect(row.status).to eq('failed')
        expect(row.error_code).to be_present
        expect(row.message.status).to eq('error')
        expect(victim.reload.sms_invitation_sent_at).to be_nil
        expect(pups.drop(1).map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_present)
        campaign.reload
        expect([campaign.failed_count, campaign.accepted_count]).to eq([1, 2])
        expect(campaign.status).to eq('sent')
        expect(campaign.sent_at).to be_present
      end

      it 'a recipient whose send failed is still in the recipient scope of the invitation' do
        campaign, pups = prepare(count: 2)
        fail_provider_for([phone_of(pups.first)])

        run_job(campaign)

        expect(provider.calls.size).to eq(2)
        expect(PredefinedParticipants::SmsRecipientsQuery.call(campaign).map(&:id)).to eq([pups.first.id])
      end

      it 'a body above the Twilio limit is rejected for everybody and the campaign is visibly failed, not sent' do
        campaign, pups = prepare(count: 2, body: 'x' * 1700)
        provider.on_create { |kwargs| raise rest_error(kwargs[:to], kwargs[:body].first(10)) if kwargs[:body].length > 1600 }

        run_job(campaign)

        campaign.reload
        expect(provider.calls.size).to eq(2)
        expect(campaign.deliveries.pluck(:status)).to all(eq('failed'))
        expect([campaign.accepted_count, campaign.failed_count, campaign.status]).to eq([0, 2, 'failed'])
        expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_nil)
      end

      it 'without a provider error the same set-up ends sent with every recipient stamped' do
        campaign, pups = prepare(count: 3)

        run_job(campaign)

        campaign.reload
        expect([campaign.accepted_count, campaign.failed_count, campaign.status]).to eq([3, 0, 'sent'])
        expect(pups.map { |pup| pup.reload.sms_invitation_sent_at }).to all(be_present)
        expect(campaign.deliveries.map { |row| row.message.status }).to all(eq('success'))
      end
    end

    describe 'an exception for one recipient does not stop the batch' do
      INJECTION_POINTS.each do |point|
        it "a StandardError raised at #{point} for one recipient leaves the others messaged" do
          campaign, pups = prepare(count: 3)
          victim = pups.second
          inject(point, error: RuntimeError, victim: victim)

          expect { run_job(campaign) }.not_to raise_error

          others = pups - [victim]
          expect(provider.numbers).to match_array(others.map { |pup| phone_of(pup) })
          expect(others.map { |pup| delivery_of(campaign, pup).status }).to all(eq('sent'))
          expect(victim.reload.sms_invitation_sent_at).to be_nil
          expect(delivery_of(campaign, victim)&.status).not_to eq('sent')
        end
      end

      it 'an exception at send time is recorded as a failed recipient and the campaign ends sent' do
        campaign, pups = prepare(count: 3)
        victim = pups.first
        inject(:send_message, error: RuntimeError, victim: victim)

        run_job(campaign)

        expect(delivery_of!(campaign, victim).status).to eq('failed')
        campaign.reload
        expect([campaign.failed_count, campaign.accepted_count, campaign.status]).to eq([1, 2, 'sent'])
      end

      it 'reports the exception to Sentry without aborting' do
        campaign, pups = prepare(count: 2)
        allow(Sentry).to receive(:capture_exception)
        inject(:render, error: RuntimeError, victim: pups.first)

        run_job(campaign)

        expect(Sentry).to have_received(:capture_exception).at_least(:once)
      end
    end

    describe 'JobTimeoutError passes through every per-recipient rescue' do
      INJECTION_POINTS.each do |point|
        it "a timeout raised at #{point} leaves the job instead of being recorded for one recipient" do
          campaign, = prepare(count: 3)
          inject(point, error: ApplicationJob::JobTimeoutError, nth: 2)

          expect { run_directly(campaign) }.to raise_error(ApplicationJob::JobTimeoutError)

          campaign.reload
          expect(provider.calls.size).to eq(1)
          expect(campaign.deliveries.where(status: 'failed')).to be_empty
          expect(campaign.failed_count).to eq(0)
          expect(campaign.status).to eq('sending')
          expect(campaign.sent_at).to be_nil
        end

        it "a StandardError raised at the same #{point} position is absorbed and the loop carries on" do
          campaign, = prepare(count: 3)
          inject(point, error: RuntimeError, nth: 2)

          expect { run_directly(campaign) }.not_to raise_error

          expect(provider.calls.size).to eq(2)
          expect(campaign.reload.status).not_to eq('sending')
        end
      end

      it 'a timeout leaves the claimed row pending so that only the claim protects the retry from a double SMS' do
        campaign, pups = prepare(count: 3)
        state = { on: true }
        inject(:send_message, error: ApplicationJob::JobTimeoutError, nth: 2, state: state)

        expect { run_job(campaign) }.to have_enqueued_job(described_class).with(campaign.id)
        expect(provider.calls.size).to eq(1)
        expect(campaign.deliveries.where(status: 'pending').count).to eq(1)

        state[:on] = false
        travel_to(frozen_now + 36.minutes)
        run_job(campaign)

        expect(provider.numbers).to match_array(pups.map { |pup| phone_of(pup) })
        expect(campaign.reload.status).to eq('sent')
        expect(campaign.deliveries.pluck(:status).uniq).to eq(['sent'])
      end
    end

    describe 'the sent row and the participant stamp are written together' do
      stamp_condition = 'NEW.sms_invitation_sent_at IS DISTINCT FROM OLD.sms_invitation_sent_at ' \
                        'OR NEW.last_reminder_sent_at IS DISTINCT FROM OLD.last_reminder_sent_at'

      %w[invitation manual_reminder].each do |kind|
        context "for a #{kind} campaign" do
          let(:stamped_columns) { %w[sms_invitation_sent_at last_reminder_sent_at] }

          def stamps_of(pup)
            pup.reload.slice(:sms_invitation_sent_at, :last_reminder_sent_at).values
          end

          it "when the stamp cannot be written the delivery is not left sent (#{kind})" do
            campaign, pups = prepare(kind: kind, count: 1)
            before = stamps_of(pups.first)
            install_raising_trigger('tdd_fail_stamp', 'predefined_user_parameters', stamp_condition)

            expect { run_job(campaign) }.not_to raise_error

            expect(delivery_of!(campaign, pups.first).status).not_to eq('sent')
            expect(stamps_of(pups.first)).to eq(before)
            expect(campaign.reload.accepted_count).to eq(0)
          end

          it "when the delivery cannot be marked sent the participant is not stamped (#{kind})" do
            campaign, pups = prepare(kind: kind, count: 1)
            before = stamps_of(pups.first)
            install_raising_trigger('tdd_fail_delivery', 'predefined_participants_sms_deliveries',
                                    "NEW.status = 'sent' AND OLD.status IS DISTINCT FROM 'sent'")

            expect { run_job(campaign) }.not_to raise_error

            expect(stamps_of(pups.first)).to eq(before)
            expect(delivery_of!(campaign, pups.first).status).not_to eq('sent')
            expect(campaign.reload.accepted_count).to eq(0)
          end

          it "when the accepted counter cannot be written neither the delivery nor the stamp survive (#{kind})" do
            campaign, pups = prepare(kind: kind, count: 1)
            before = stamps_of(pups.first)
            install_raising_trigger('tdd_fail_counter', 'predefined_participants_sms_campaigns',
                                    'NEW.accepted_count IS DISTINCT FROM OLD.accepted_count')

            expect { run_job(campaign) }.not_to raise_error

            expect(delivery_of!(campaign, pups.first).status).not_to eq('sent')
            expect(stamps_of(pups.first)).to eq(before)
          end

          it "with nothing failing both the sent row and the stamp are written (#{kind})" do
            campaign, pups = prepare(kind: kind, count: 1)
            before = stamps_of(pups.first)

            run_job(campaign)

            expect(delivery_of!(campaign, pups.first).status).to eq('sent')
            expect(stamps_of(pups.first)).not_to eq(before)
            expect(campaign.reload.accepted_count).to eq(1)
          end
        end
      end
    end

    describe 'failure bookkeeping is idempotent' do
      def delivery_for_body(campaign, body) = PredefinedParticipants::SmsDelivery.find_by!(campaign_id: campaign.id, body: body)

      def raise_after(campaign, &before_raise)
        allow_any_instance_of(Communication::Sms).to receive(:send_message) do |instance|
          before_raise.call(delivery_for_body(campaign, instance.sms.body)) # rubocop:disable Performance/RedundantBlockCall
          raise 'injected after claim'
        end
      end

      it 'a delivery that is already sent is never flipped to failed by the surrounding rescue' do
        campaign, = prepare(count: 1)
        raise_after(campaign) { |row| row.update_columns(status: 'sent', sent_at: Time.current) }

        run_job(campaign)

        expect(campaign.deliveries.count).to eq(1)
        expect(campaign.deliveries.first.status).to eq('sent')
        expect(campaign.reload.failed_count).to eq(0)
      end

      it 'a delivery that is already failed does not raise failed_count a second time' do
        campaign, = prepare(count: 1)
        raise_after(campaign) do |row|
          row.update_columns(status: 'failed', error_code: 'RuntimeError')
          PredefinedParticipants::SmsCampaign.where(id: campaign.id).update_all('failed_count = failed_count + 1')
        end

        run_job(campaign)

        expect(campaign.deliveries.count).to eq(1)
        expect(campaign.deliveries.first.status).to eq('failed')
        expect(campaign.reload.failed_count).to eq(1)
      end

      it 'an exception on a pending row marks it failed and counts it exactly once' do
        campaign, = prepare(count: 1)
        raise_after(campaign) { |_row| nil }

        run_job(campaign)

        expect(campaign.deliveries.count).to eq(1)
        expect(campaign.deliveries.first.status).to eq('failed')
        expect(campaign.reload.failed_count).to eq(1)
      end

      it 'counters are applied atomically, so a concurrent increment is not lost' do
        campaign, = prepare(count: 2)
        bumped = false
        provider.on_create do
          next if bumped

          bumped = true
          PredefinedParticipants::SmsCampaign.where(id: campaign.id).update_all('accepted_count = accepted_count + 5')
        end

        run_job(campaign)

        expect(campaign.reload.accepted_count).to eq(7)
      end

      it 'failed_count has no hidden starting value: a resumed run adds to what is stored' do
        campaign, pups = prepare(count: 2, status: 'sending', failed_count: 4)
        fail_provider_for([phone_of(pups.first)])

        run_job(campaign)

        expect(campaign.reload.failed_count).to eq(5)
      end
    end

    describe 'closing the campaign' do
      it 'with no failed recipient the campaign is sent and sent_at is set' do
        campaign, = prepare(count: 2)

        run_job(campaign)

        campaign.reload
        expect(campaign.status).to eq('sent')
        expect(campaign.sent_at).to be_within(1.second).of(frozen_now)
      end

      it 'with one failed recipient the campaign is sent and sent_at is set' do
        campaign, pups = prepare(count: 2)
        fail_provider_for([phone_of(pups.last)])

        run_job(campaign)

        campaign.reload
        expect(campaign.status).to eq('sent')
        expect(campaign.failed_count).to eq(1)
        expect(campaign.sent_at).to be_within(1.second).of(frozen_now)
      end

      it 'the campaign is never left in sending after a completed run' do
        campaign, = prepare(count: 2)

        run_job(campaign)

        expect(campaign.reload.status).to be_in(%w[sent failed])
      end
    end

    describe 'stamping writes the right column and nothing else' do
      def writable_snapshot(pup, except)
        pup.reload.attributes.except('updated_at', *except)
      end

      it 'an invitation stamps sms_invitation_sent_at only' do
        campaign, pups = prepare(kind: 'invitation', count: 1)
        before = writable_snapshot(pups.first, ['sms_invitation_sent_at'])
        events = record_enqueues { run_job(campaign) }

        pup = pups.first.reload
        expect(pup.sms_invitation_sent_at).to be_within(1.second).of(frozen_now)
        expect(pup.last_reminder_sent_at).to be_nil
        expect(writable_snapshot(pup, ['sms_invitation_sent_at'])).to eq(before)
        expect(events).to be_empty
      end

      it 'a manual reminder stamps last_reminder_sent_at and leaves the invitation stamp as it was' do
        campaign, pups = prepare(kind: 'manual_reminder', count: 1)
        invited = pups.first.reload.sms_invitation_sent_at
        before = writable_snapshot(pups.first, ['last_reminder_sent_at'])
        events = record_enqueues { run_job(campaign) }

        pup = pups.first.reload
        expect(pup.last_reminder_sent_at).to be_within(1.second).of(frozen_now)
        expect(pup.sms_invitation_sent_at).to eq(invited)
        expect(writable_snapshot(pup, ['last_reminder_sent_at'])).to eq(before)
        expect(events).to be_empty
      end

      it 'a scheduled reminder stamps last_reminder_sent_at and leaves the invitation stamp and first_opened_at alone' do
        campaign, pups = prepare(kind: 'scheduled_reminder', count: 1)
        invited = pups.first.reload.sms_invitation_sent_at
        before = writable_snapshot(pups.first, ['last_reminder_sent_at'])
        events = record_enqueues { run_job(campaign) }

        pup = pups.first.reload
        expect(provider.calls.size).to eq(1)
        expect(pup.last_reminder_sent_at).to be_within(1.second).of(frozen_now)
        expect(pup.sms_invitation_sent_at).to eq(invited)
        expect(pup.first_opened_at).to be_nil
        expect(writable_snapshot(pup, ['last_reminder_sent_at'])).to eq(before)
        expect(events).to be_empty
      end

      it 'a recipient whose send failed receives no stamp of any kind' do
        campaign, pups = prepare(kind: 'manual_reminder', count: 1)
        fail_provider_for([phone_of(pups.first)])
        before = pups.first.reload.slice(:sms_invitation_sent_at, :last_reminder_sent_at)

        run_job(campaign)

        expect(provider.calls.size).to eq(1)
        expect(pups.first.reload.slice(:sms_invitation_sent_at, :last_reminder_sent_at)).to eq(before)
      end
    end

    describe 'no number or message text is persisted or logged for a provider failure' do
      let(:log_io) { StringIO.new }
      let(:log_probe) { ActiveSupport::Logger.new(log_io) }

      def with_captured_logs
        sql_logger = ActiveRecord::Base.logger
        ActiveRecord::Base.logger = nil
        Rails.logger.broadcast_to(log_probe)
        yield
      ensure
        Rails.logger.stop_broadcasting_to(log_probe)
        ActiveRecord::Base.logger = sql_logger
      end

      def leak_markers(pups)
        pups.flat_map { |pup| [phone_of(pup), phone_of(pup).delete('+'), pup.user.phone.number, canary_body, pup.slug] }
      end

      it 'error_code carries only a class name or a numeric code' do
        campaign, pups = prepare(count: 2)
        fail_provider_for(pups.map { |pup| phone_of(pup) })

        run_job(campaign)

        codes = campaign.deliveries.pluck(:error_code)
        expect(codes.size).to eq(2)
        expect(codes).to all(match(/\A(\d{3,6}|[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*)\z/))
        markers = leak_markers(pups)
        codes.each { |code| markers.each { |marker| expect(code).not_to include(marker) } }
      end

      it 'neither the logs nor Sentry receive a number, the message text or a personal slug' do
        campaign, pups = prepare(count: 2)
        fail_provider_for(pups.map { |pup| phone_of(pup) })
        sentry_args = []
        %i[capture_exception capture_message set_context set_extras].each do |meth|
          allow(Sentry).to receive(meth) { |*args, **kwargs| sentry_args << [args, kwargs].inspect }
        end

        with_captured_logs { run_job(campaign) }

        expect(campaign.deliveries.pluck(:status)).to eq(%w[failed failed])
        markers = leak_markers(pups)
        markers.each do |marker|
          expect(log_io.string).not_to include(marker)
          expect(sentry_args.join).not_to include(marker)
        end
      end

      it 'the leak detector would catch a number and a canary' do
        _campaign, pups = prepare(count: 1)
        with_captured_logs { Rails.logger.info("leak #{phone_of(pups.first)} #{canary_body}") }

        expect(leak_markers(pups).count { |marker| log_io.string.include?(marker) }).to be >= 1
      end

      it 'the provider really received the number and the text that must not leak' do
        campaign, pups = prepare(count: 1)
        fail_provider_for([phone_of(pups.first)])

        run_job(campaign)

        expect(provider.calls.size).to eq(1)
        expect(provider.calls.first[:to]).to eq(phone_of(pups.first))
        expect(provider.calls.first[:body]).to include(canary_body)
        expect(campaign.deliveries.first.error_code).to be_present
      end
    end

    describe 'the job argument is the campaign id' do
      it 'the serialized job carries the campaign id and no number, text or slug' do
        campaign, pups = prepare(count: 1)

        payload = described_class.new(campaign.id).serialize

        expect(payload['arguments']).to eq([campaign.id])
        json = payload.to_json
        [phone_of(pups.first), pups.first.user.phone.number, canary_body, pups.first.slug].each do |secret|
          expect(json).not_to include(secret)
        end
      end

      it 'an enqueued job holds only the id' do
        campaign, = prepare(count: 1)

        described_class.perform_later(campaign.id)

        entry = campaign_jobs.last
        expect(entry[:args]).to eq([campaign.id])
      end

      it 'given only the id the job resolves the number and the text itself' do
        campaign, pups = prepare(count: 1)

        described_class.perform_now(campaign.id)

        expect(provider.calls.size).to eq(1)
        expect(provider.calls.first[:to]).to eq(phone_of(pups.first))
        expect(provider.calls.first[:body]).to eq(expected_body(pups.first))
      end

      it 'the detector would flag a job that is handed a number and a text' do
        leaky = SmsPlans::SendSmsJob.new('+12015550123', canary_body, nil, nil).serialize.to_json

        expect(leaky).to include('+12015550123')
        expect(leaky).to include(canary_body)
      end
    end

    describe 'queue' do
      it 'the job runs on the sms_plans queue' do
        expect(described_class.new.queue_name).to eq('sms_plans')
      end

      it 'an enqueued job lands on sms_plans, a queue that sidekiq.yml actually serves' do
        campaign, = prepare(count: 1)
        described_class.perform_later(campaign.id)

        queue = campaign_jobs.last[:queue]
        config = YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result, permitted_classes: [Symbol], symbolize_names: true)
        served = config[:queues].map { |entry| Array(entry).first.to_s }

        expect(queue).to eq('sms_plans')
        expect(served).to include(queue)
      end

      it 'the queue check would reject a queue Sidekiq does not serve' do
        config = YAML.safe_load(ERB.new(Rails.root.join('config/sidekiq.yml').read).result, permitted_classes: [Symbol], symbolize_names: true)
        served = config[:queues].map { |entry| Array(entry).first.to_s }

        expect(served).not_to include('sms_plans_typo')
      end

      it 'the job enqueued on sms_plans does its work when executed from the queue payload' do
        campaign, pups = prepare(count: 1)
        described_class.perform_later(campaign.id)
        entry = campaign_jobs.last
        expect(entry[:queue]).to eq('sms_plans')

        ActiveJob::Base.execute(entry.except(:job, :args, :queue).stringify_keys)

        expect(provider.numbers).to eq([phone_of(pups.first)])
      end
    end

    describe 'the loop never reloads the campaign or per-recipient associations' do
      def selects_from(queries, table)
        queries.count { |sql| sql.start_with?('SELECT') && sql.include?(%(FROM "#{table}")) }
      end

      def world(count, offset)
        owner = create(:intervention, :published)
        campaign, = prepare(count: count, offset: offset, owner: owner, body: "#{canary_body} ::#{canary_variable}::")
        create(:pdp_campaign_sms_link, campaign: campaign, variable: canary_variable, url: canary_url)
        campaign
      end

      it 'selects on campaigns, sms_links, phones and users do not grow with the number of recipients' do
        small = world(2, 0)
        before = provider.calls.size
        small_queries = collect_queries { run_job(small) }
        expect(provider.calls.size - before).to eq(2)

        large = world(6, 2)
        before = provider.calls.size
        large_queries = collect_queries { run_job(large) }
        expect(provider.calls.size - before).to eq(6)

        %w[predefined_participants_sms_campaigns sms_links phones users].each do |table|
          expect(selects_from(large_queries, table)).to eq(selects_from(small_queries, table)), "SELECT count on #{table} grew with N"
        end
      end
    end

    describe 'opt-out guard on every send' do
      it 'blocks a recipient whose number is shared with another user who opted out' do
        campaign, pups = prepare(count: 2)
        shared = pups.first.user.phone
        other = create(:user, :confirmed, :participant)
        create(:phone, user: other, iso: shared.iso, prefix: shared.prefix, number: shared.number)
        create(:pdp_sms_opt_out, user: other)

        run_job(campaign)

        expect(provider.numbers).to eq([phone_of(pups.second)])
      end

      it 'blocks a recipient who opts out while the campaign is sending' do
        campaign, pups = prepare(count: 2)
        provider.on_create do |kwargs|
          pups.reject { |pup| phone_of(pup) == kwargs[:to] }.each { |pup| create(:pdp_sms_opt_out, user: pup.user) }
        end

        run_job(campaign)

        expect(provider.calls.size).to eq(1)
      end
    end
  end
end
