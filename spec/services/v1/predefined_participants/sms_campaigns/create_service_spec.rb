# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PredefinedParticipants::SmsCampaigns::CreateService do
  context 'with two invitable participants' do
    include PredefinedParticipantSmsHelpers

    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:pup_one) { make_participant(intervention, index: 0) }
    let!(:pup_two) { make_participant(intervention, index: 1) }

    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    before do
      allow(Sentry).to receive(:capture_exception)
      travel_to(frozen_now)
    end

    def service_class
      V1::PredefinedParticipants::SmsCampaigns::CreateService
    end

    def campaign_params(**overrides)
      { kind: 'invitation', body: canary_body, links: [] }.merge(overrides).with_indifferent_access
    end

    def link_param(variable: canary_variable, url: canary_url)
      { url: url, variable: variable, link_type: 'website' }
    end

    def run_service(params = campaign_params, target: intervention)
      service_class.call(target, researcher, params)
    end

    def campaigns(target = intervention)
      PredefinedParticipants::SmsCampaign.where(intervention_id: target.id)
    end

    def expect_rejected_with_codes(exception)
      expect(exception).to be_a(ComplexException)
      expect(http_status(exception)).to eq(422)
      expect(error_codes(exception)).not_to be_empty
      expect(error_codes(exception)).to all(match(/\A[A-Za-z0-9_.:-]+\z/))
      expect(exception.message).not_to include(canary_body)
    end

    def send_job_events(events)
      events.select { |event| event[:class_name] == 'PredefinedParticipants::SendSmsCampaignJob' }
    end

    describe 'refuses an intervention that is not published' do
      {
        'draft' => ['INTERVENTION_DRAFT', {}],
        'paused' => ['INTERVENTION_PAUSED', { status: 'paused' }],
        'closed' => ['INTERVENTION_CLOSED', { status: 'closed' }]
      }.each do |label, (reason, attributes)|
        it "raises a 400 ComplexException with reason #{reason} for a #{label} intervention and creates nothing" do
          target = create(:intervention, user: researcher, **attributes)
          make_participant(target, index: 2)
          exception = capture_complex_exception { run_service(campaign_params, target: target) }
          expect(exception).to be_a(ComplexException)
          expect(http_status(exception)).to eq(400)
          expect(exception.additional_information.with_indifferent_access[:reason]).to eq(reason)
          expect(campaigns(target)).to be_empty
        end
      end

      it 'creates a scheduled campaign owned by the author for a published intervention' do
        run_service
        campaign = campaigns.sole
        expect(campaign).to have_attributes(kind: 'invitation', status: 'scheduled', body: canary_body, author_id: researcher.id,
                                            recipients_count: 2, days_after: nil)
        expect(campaign.scheduled_at).to be_within(1.second).of(Time.current)
      end
    end

    describe 'payload validation answers 422 with codes' do
      it 'never creates a scheduled_reminder as a standalone campaign' do
        exception = capture_complex_exception { run_service(campaign_params(kind: 'scheduled_reminder')) }
        expect_rejected_with_codes(exception)
        expect(campaigns).to be_empty
        expect { run_service(campaign_params(kind: 'invitation')) }.not_to raise_error
        expect(campaigns.count).to eq(1)
      end

      it 'rejects an unknown kind with a coded 422 and not with an ArgumentError' do
        exception = capture_complex_exception { run_service(campaign_params(kind: 'bogus')) }
        expect_rejected_with_codes(exception)
        expect(campaigns).to be_empty
      end

      it 'accepts a manual_reminder once participants were invited' do
        [pup_one, pup_two].each { |pup| pup.update!(sms_invitation_sent_at: 2.days.ago) }
        expect { run_service(campaign_params(kind: 'manual_reminder')) }.not_to raise_error
        expect(campaigns.sole.kind).to eq('manual_reminder')
      end
    end

    describe 'variables and links must match both ways' do
      it 'rejects a ::variable:: used in the body but missing from links, and accepts it once the link is present' do
        body = "#{canary_body} ::#{canary_variable}::"
        exception = capture_complex_exception { run_service(campaign_params(body: body, links: [])) }
        expect_rejected_with_codes(exception)
        expect(campaigns).to be_empty
        run_service(campaign_params(body: body, links: [link_param]))
        expect(campaigns.sole.sms_links.pluck(:variable)).to eq([canary_variable])
      end

      it 'rejects a link whose variable does not occur in the body, and accepts it once the body uses it' do
        exception = capture_complex_exception { run_service(campaign_params(body: canary_body, links: [link_param])) }
        expect_rejected_with_codes(exception)
        expect(campaigns).to be_empty
        run_service(campaign_params(body: "#{canary_body} ::#{canary_variable}::", links: [link_param]))
        expect(campaigns.count).to eq(1)
      end

      it 'rejects a body variable that differs from the link variable' do
        exception = capture_complex_exception do
          run_service(campaign_params(body: "#{canary_body} ::other_link::", links: [link_param]))
        end
        expect_rejected_with_codes(exception)
        expect(campaigns).to be_empty
      end

      it 'rejects two links with the same variable as a coded 422 and not as a database error' do
        body = "#{canary_body} ::#{canary_variable}::"
        links = [link_param, link_param(url: "#{canary_url}-two")]
        exception = capture_complex_exception { run_service(campaign_params(body: body, links: links)) }
        expect_rejected_with_codes(exception)
        expect(campaigns).to be_empty
        expect(SmsLink.where(variable: canary_variable)).to be_empty
        run_service(campaign_params(body: body, links: [link_param]))
        expect(campaigns.count).to eq(1)
      end
    end

    describe 'normalisation and forbidden characters' do
      it 'stores the body in Unicode NFC' do
        decomposed = "Café #{canary_body}"
        expect(decomposed).not_to eq(decomposed.unicode_normalize(:nfc))
        run_service(campaign_params(body: decomposed))
        expect(campaigns.sole.body).to eq(decomposed.unicode_normalize(:nfc))
      end

      {
        'a NUL control character' => "\u0000",
        'a BEL control character' => "\u0007",
        'a zero width space' => '​',
        'a word joiner' => '⁠',
        'a byte order mark' => '﻿'
      }.each do |label, character|
        it "rejects a body containing #{label} and accepts the same body without it" do
          exception = capture_complex_exception { run_service(campaign_params(body: "#{canary_body}#{character}tail")) }
          expect_rejected_with_codes(exception)
          expect(campaigns).to be_empty
          run_service(campaign_params(body: "#{canary_body}tail"))
          expect(campaigns.sole.body).to eq("#{canary_body}tail")
        end
      end
    end

    describe 'body length after link expansion' do
      let(:limit) { Settings.sms_campaigns.max_body_length }
      let(:room) { limit - 1 - personal_link_expected_length }

      def rejected_codes(params)
        exception = capture_complex_exception { run_service(params) }
        expect_rejected_with_codes(exception)
        error_codes(exception)
      end

      it 'rejects a GSM-7 body whose personal link pushes it over the limit and accepts it one character shorter' do
        expect(rejected_codes(campaign_params(body: 'a' * (room + 1)))).to include('BODY_TOO_LONG')
        expect(campaigns).to be_empty
        run_service(campaign_params(body: 'a' * room))
        expect(campaigns.count).to eq(1)
      end

      it 'rejects a UCS-2 body over the limit and accepts it at the limit' do
        expect(rejected_codes(campaign_params(body: 'ą' * (room + 1)))).to include('BODY_TOO_LONG')
        run_service(campaign_params(body: 'ą' * room))
        expect(campaigns.count).to eq(1)
      end

      it 'counts every tracked link at its expected length' do
        body = "#{'a' * (room - tracked_link_expected_length + 1)}::#{canary_variable}::"
        expect(rejected_codes(campaign_params(body: body, links: [link_param]))).to include('BODY_TOO_LONG')
        run_service(campaign_params(body: body.sub('a', ''), links: [link_param]))
        expect(campaigns.count).to eq(1)
      end
    end

    describe 'empty recipient set' do
      it 'refuses an invitation when nobody is left to invite and accepts it once somebody is' do
        [pup_one, pup_two].each { |pup| pup.update!(sms_invitation_sent_at: 1.day.ago) }
        exception = capture_complex_exception { run_service }
        expect(http_status(exception)).to eq(422)
        expect(error_codes(exception)).to include('NO_RECIPIENTS')
        expect(campaigns).to be_empty
        make_participant(intervention, index: 3)
        run_service
        expect(campaigns.count).to eq(1)
      end

      it 'refuses a manual_reminder when nobody was invited and accepts it once somebody was' do
        exception = capture_complex_exception { run_service(campaign_params(kind: 'manual_reminder')) }
        expect(http_status(exception)).to eq(422)
        expect(error_codes(exception)).to include('NO_RECIPIENTS')
        expect(campaigns).to be_empty
        pup_one.update!(sms_invitation_sent_at: 1.day.ago)
        run_service(campaign_params(kind: 'manual_reminder'))
        expect(campaigns.count).to eq(1)
      end

      it 'enqueues nothing for a refused campaign' do
        [pup_one, pup_two].each { |pup| pup.update!(sms_invitation_sent_at: 1.day.ago) }
        events = record_enqueues { capture_complex_exception { run_service } }
        expect(events).to be_empty
      end
    end

    describe 'overlapping campaign of the same immediate kind' do
      %w[scheduled sending].each do |status|
        it "answers 409 without SQL details when an invitation in status #{status} is in flight" do
          create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: status)
          exception = capture_complex_exception { run_service }
          expect(exception).to be_a(ComplexException)
          expect(http_status(exception)).to eq(409)
          expect(error_codes(exception)).not_to be_empty
          serialized = [exception.message, exception.additional_information.to_json].join(' ')
          expect(serialized).not_to match(/index_pp_sms_campaigns|PG::|duplicate key|violates|RecordNotUnique/i)
          expect(campaigns.count).to eq(1)
        end
      end

      it 'does not conflict with an invitation that already finished' do
        create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent')
        run_service
        expect(campaigns.where(status: 'scheduled').count).to eq(1)
      end

      it 'does not conflict with an in flight campaign of another kind' do
        create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'scheduled')
        run_service
        expect(campaigns.where(kind: 'invitation').count).to eq(1)
      end

      it 'does not conflict with an in flight invitation of another intervention' do
        create(:pdp_sms_campaign, intervention: create(:intervention, :published), kind: 'invitation', status: 'scheduled')
        run_service
        expect(campaigns.count).to eq(1)
      end
    end

    describe 'campaign and links are created in one transaction' do
      let(:body) { "#{canary_body} ::#{canary_variable}:: ::canary_link_two::" }
      let(:good_link) { link_param }
      let(:other_link) { link_param(variable: 'canary_link_two', url: "#{canary_url}-two") }
      let(:bad_link) { link_param(variable: 'canary_link_two', url: 'javascript://canary') }

      it 'persists the campaign together with all its links' do
        run_service(campaign_params(body: body, links: [good_link, other_link]))
        campaign = campaigns.sole
        expect(campaign.sms_links.pluck(:variable)).to contain_exactly(canary_variable, 'canary_link_two')
        expect(campaign.sms_links.pluck(:campaign_id).uniq).to eq([campaign.id])
      end

      it 'leaves no campaign and no link behind when the second link is invalid' do
        before_links = SmsLink.count
        exception = capture_complex_exception { run_service(campaign_params(body: body, links: [good_link, bad_link])) }
        expect(exception).to be_present
        expect(campaigns).to be_empty
        expect(SmsLink.count).to eq(before_links)
      end

      it 'enqueues nothing when the campaign was rolled back' do
        events = record_enqueues { capture_complex_exception { run_service(campaign_params(body: body, links: [good_link, bad_link])) } }
        expect(send_job_events(events)).to be_empty
      end

      it 'lets two successive campaigns use the same link url and variable' do
        body_one = "#{canary_body} ::#{canary_variable}::"
        run_service(campaign_params(body: body_one, links: [good_link]))
        campaigns.update_all(status: 'sent')
        run_service(campaign_params(body: body_one, links: [good_link]))
        expect(campaigns.count).to eq(2)
        expect(SmsLink.where(campaign_id: campaigns.ids).count).to eq(2)
      end
    end

    describe 'enqueue after the transaction commits' do
      it 'enqueues the campaign job once, outside any transaction opened by the service, with the campaign id' do
        baseline = transaction_depth
        events = record_enqueues { run_service }
        jobs = send_job_events(events)
        expect(jobs.size).to eq(1)
        expect(jobs.first[:arguments]).to eq([campaigns.sole.id])
        expect(jobs.first[:depth]).to eq(baseline)
      end
    end

    describe 'enqueue failure' do
      it 'keeps the campaign in scheduled and does not mark it failed when perform_later raises' do
        healthy = ActiveJob::Base.queue_adapter
        failing = PredefinedParticipantSmsHelpers::FailingQueueAdapter.new
        ActiveJob::Base.queue_adapter = failing
        begin
          run_service
        rescue NameError
          raise
        rescue StandardError
          nil
        ensure
          ActiveJob::Base.queue_adapter = healthy
        end
        expect(failing.attempts).to be_positive
        expect(campaigns.pluck(:status)).to eq(['scheduled'])
      end
    end
  end

  context 'with one invitable recipient', type: :service do
    include ActiveSupport::Testing::TimeHelpers
    include ActiveJob::TestHelper
    include PredefinedParticipantSmsHelpers

    around { |example| travel_to(PredefinedParticipantSmsHelpers::NOW) { example.run } }

    let(:service) { 'V1::PredefinedParticipants::SmsCampaigns::CreateService'.constantize }
    let(:job_class) { PredefinedParticipants::SendSmsCampaignJob }
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:intervention) { create(:intervention, :published, user: researcher) }
    let!(:recipient) { create_participant(intervention) }
    let(:body) { PredefinedParticipantSmsHelpers::CANARY_BODY }
    let(:kind) { 'invitation' }
    let(:links) { [] }
    let(:reminder) { nil }
    let(:params) { build_params }

    before { stub_web_url }

    def build_params(kind: self.kind, body: self.body, links: self.links, scheduled_reminder: reminder)
      payload = { kind: kind, body: body, links: links }
      payload[:scheduled_reminder] = scheduled_reminder if scheduled_reminder
      ActionController::Parameters.new(payload).permit!
    end

    def call_service(payload = params)
      service.call(intervention, researcher, payload)
    end

    def campaign_jobs
      enqueued_jobs.select { |job| job['job_class'] == job_class.name }
    end

    def campaigns
      PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id)
    end

    def rejection(payload = params)
      capture_complex_exception { call_service(payload) }
    end

    def expect_validation_failure(exception)
      expect(exception).to be_a(ComplexException)
      expect(PredefinedParticipantSmsHelpers::UNPROCESSABLE).to include(exception.status_code)
      codes = codes_of(exception)
      expect(codes).not_to be_empty
      expect(codes).to all(match(/\A\w+\z/))
      expect(codes).not_to include('NO_RECIPIENTS', 'TOO_MANY_RECIPIENTS', 'INTERVENTION_DRAFT')
      expect([exception.message, info_of(exception).to_s].join).not_to match(PredefinedParticipantSmsHelpers::LEAKY_SQL)
      expect(campaigns.count).to eq(0)
      expect(campaign_jobs).to be_empty
    end

    describe 'the campaign and its links are created together' do
      let(:body) { "#{PredefinedParticipantSmsHelpers::CANARY_BODY} ::canary_link::" }
      let(:links) { [link_params] }

      it 'persists one scheduled campaign with its link, the author and the immediate scheduled_at' do
        call_service
        campaign = campaigns.sole
        expect(campaign).to have_attributes(kind: 'invitation', status: 'scheduled', body: body, author_id: researcher.id)
        expect(campaign.scheduled_at).to eq(PredefinedParticipantSmsHelpers::NOW)
        expect(campaign.sms_links.map { |l| [l.variable, l.url] }).to eq([['canary_link', PredefinedParticipantSmsHelpers::TRACKED_URL]])
        expect(campaign_jobs.map { |job| [job['job_class'], job['arguments']] }).to eq([[job_class.name, [campaign.id]]])
      end

      context 'when the second link is invalid' do
        let(:body) { "#{PredefinedParticipantSmsHelpers::CANARY_BODY} ::canary_link:: ::canary_link_two::" }
        let(:links) { [link_params, link_params(variable: 'canary_link_two', url: 'javascript://canary')] }

        it 'leaves no campaign and no link behind and enqueues nothing' do
          campaign_count = PredefinedParticipants::SmsCampaign.count
          link_count = SmsLink.count
          expect { call_service }.to raise_error(ComplexException)
          expect(PredefinedParticipants::SmsCampaign.count).to eq(campaign_count)
          expect(SmsLink.count).to eq(link_count)
          expect(campaign_jobs).to be_empty
        end
      end
    end

    describe 'intervention must be published' do
      {
        draft: 'INTERVENTION_DRAFT',
        paused: 'INTERVENTION_PAUSED',
        closed: 'INTERVENTION_CLOSED'
      }.each do |trait, reason|
        context "when the intervention is #{trait}" do
          let(:intervention) { trait == :draft ? create(:intervention, user: researcher) : create(:intervention, trait, user: researcher) }

          it "raises ComplexException 400 with reason #{reason} and creates nothing" do
            exception = rejection
            expect(exception).to be_a(ComplexException)
            expect(PredefinedParticipantSmsHelpers::BAD_REQUEST).to include(exception.status_code)
            expect(info_of(exception)[:reason]).to eq(reason)
            expect(campaigns.count).to eq(0)
            expect(campaign_jobs).to be_empty
          end
        end
      end

      it 'accepts the same payload for a published intervention' do
        expect(rejection).to be_nil
        expect(campaigns.count).to eq(1)
      end
    end

    describe 'scheduled reminder sent with the invitation' do
      let(:reminder) { { body: 'CIAS_TDD_REMINDER_BODY', days_after: 3 } }

      def reminder_campaign
        campaigns.find_by(kind: 'scheduled_reminder')
      end

      it 'creates the reminder as a scheduled child of the invitation with its own text' do
        invitation = call_service
        expect(reminder_campaign).to have_attributes(parent_campaign_id: invitation.id, body: 'CIAS_TDD_REMINDER_BODY', days_after: 3,
                                                     status: 'scheduled', author_id: researcher.id)
      end

      it 'schedules the reminder X days after the invitation at the same time of day in the researcher time zone' do
        researcher.update!(time_zone: 'America/New_York')
        call_service
        local = reminder_campaign.scheduled_at.in_time_zone('America/New_York')
        expect(local.to_date).to eq(Date.new(2026, 11, 2))
        expect(local.strftime('%H:%M')).to eq('08:00')
      end

      it 'enqueues the reminder job for its scheduled_at next to the invitation job' do
        invitation = call_service
        child = reminder_campaign
        expect(campaign_jobs.pluck('arguments')).to contain_exactly([invitation.id], [child.id])
        scheduled_at = Time.zone.parse(campaign_jobs.find { |job| job['arguments'] == [child.id] }['scheduled_at'].to_s)
        expect(scheduled_at).to be_within(1.second).of(child.scheduled_at)
      end

      it 'creates the tracked links of the reminder on the reminder' do
        payload = build_params(scheduled_reminder: { body: 'Remind ::canary_link::', days_after: 3, links: [link_params] })
        call_service(payload)
        expect(reminder_campaign.sms_links.pluck(:variable)).to eq(['canary_link'])
        expect(campaigns.find_by(kind: 'invitation').sms_links).to be_empty
      end

      it 'is refused next to a manual reminder' do
        create_participant(intervention, sms_invitation_sent_at: 3.days.ago)
        exception = rejection(build_params(kind: 'manual_reminder'))
        expect_validation_failure(exception)
        expect(codes_of(exception)).to eq(['SCHEDULED_REMINDER_NOT_ALLOWED'])
      end

      [0, -1, 61, 'abc', nil].each do |value|
        it "refuses days_after #{value.inspect} and creates neither campaign" do
          exception = rejection(build_params(scheduled_reminder: { body: 'Remind', days_after: value }))
          expect_validation_failure(exception)
          expect(codes_of(exception)).to eq(['INVALID_DAYS_AFTER'])
        end
      end

      it 'accepts the configured maximum of days_after' do
        expect(rejection(build_params(scheduled_reminder: { body: 'Remind', days_after: 60 }))).to be_nil
      end

      it 'validates the reminder text like the invitation text, with prefixed codes' do
        exception = rejection(build_params(scheduled_reminder: { body: ' ', days_after: 3 }))
        expect_validation_failure(exception)
        expect(codes_of(exception)).to eq(['SCHEDULED_REMINDER_BODY_BLANK'])
      end

      it 'refuses a reminder variable without a link' do
        exception = rejection(build_params(scheduled_reminder: { body: 'Remind ::missing::', days_after: 3 }))
        expect_validation_failure(exception)
        expect(codes_of(exception)).to eq(['SCHEDULED_REMINDER_UNKNOWN_LINK_VARIABLE'])
      end
    end

    describe 'kind' do
      it 'never creates a scheduled_reminder as a standalone campaign' do
        expect_validation_failure(rejection(build_params(kind: 'scheduled_reminder')))
      end

      it 'rejects an unknown kind' do
        expect_validation_failure(rejection(build_params(kind: 'bogus')))
      end

      it 'accepts manual_reminder' do
        create_participant(intervention, sms_invitation_sent_at: 3.days.ago)
        expect(rejection(build_params(kind: 'manual_reminder', scheduled_reminder: nil))).to be_nil
        expect(campaigns.pluck(:kind)).to eq(['manual_reminder'])
      end
    end

    describe 'every ::variable:: in the body has a link and every link has a variable' do
      let(:body) { "#{PredefinedParticipantSmsHelpers::CANARY_BODY} ::canary_link::" }
      let(:links) { [link_params] }

      it 'accepts a body and links that match' do
        expect(rejection).to be_nil
        expect(campaigns.sole.sms_links.pluck(:variable)).to eq(['canary_link'])
      end

      it 'rejects a body variable that has no link' do
        expect_validation_failure(rejection(build_params(links: [])))
      end

      it 'rejects a link whose variable is not in the body' do
        expect_validation_failure(rejection(build_params(body: PredefinedParticipantSmsHelpers::CANARY_BODY)))
      end

      it 'rejects two links with the same variable before saving anything' do
        expect_validation_failure(rejection(build_params(links: [link_params, link_params(url: "#{PredefinedParticipantSmsHelpers::TRACKED_URL}-2")])))
      end

      it 'rejects a body variable that differs from the link variable' do
        expect_validation_failure(rejection(build_params(body: "#{PredefinedParticipantSmsHelpers::CANARY_BODY} ::other_link::")))
      end
    end

    describe 'normalisation and forbidden characters' do
      it 'stores the body in Unicode NFC' do
        decomposed = "#{PredefinedParticipantSmsHelpers::CANARY_BODY} é"
        expect(decomposed).not_to eq(decomposed.unicode_normalize(:nfc))
        call_service(build_params(body: decomposed))
        expect(campaigns.sole.body).to eq("#{PredefinedParticipantSmsHelpers::CANARY_BODY} é")
      end

      {
        'BEL control character' => "\u0007",
        'NUL control character' => "\u0000",
        'zero width space' => '​',
        'zero width joiner' => '‍',
        'byte order mark' => '﻿',
        'word joiner' => '⁠'
      }.each do |label, character|
        it "rejects a body containing a #{label}" do
          expect_validation_failure(rejection(build_params(body: "#{PredefinedParticipantSmsHelpers::CANARY_BODY}#{character}tail")))
        end
      end

      it 'accepts a plain body' do
        expect(rejection(build_params(body: "#{PredefinedParticipantSmsHelpers::CANARY_BODY} plain"))).to be_nil
      end
    end

    describe 'empty recipient set' do
      context 'when nobody is eligible for the invitation' do
        before { recipient.user.update!(active: false) }

        it 'raises 422 NO_RECIPIENTS and creates nothing' do
          exception = rejection
          expect(exception).to be_a(ComplexException)
          expect(PredefinedParticipantSmsHelpers::UNPROCESSABLE).to include(exception.status_code)
          expect(codes_of(exception)).to include('NO_RECIPIENTS')
          expect(campaigns.count).to eq(0)
          expect(campaign_jobs).to be_empty
        end
      end

      it 'refuses a manual reminder when nobody has been invited yet' do
        exception = rejection(build_params(kind: 'manual_reminder'))
        expect(exception).to be_a(ComplexException)
        expect(codes_of(exception)).to include('NO_RECIPIENTS')
        expect(campaigns.count).to eq(0)
      end

      it 'refuses when the only participant is on the opt-out list' do
        create(:pdp_sms_opt_out, user: recipient.user)
        expect(codes_of(rejection)).to include('NO_RECIPIENTS')
      end
    end

    describe 'overlapping campaign of the same immediate kind' do
      it 'answers 409 with a code and no SQL text for a second in-flight invitation' do
        call_service
        exception = rejection
        expect(exception).to be_a(ComplexException)
        expect(PredefinedParticipantSmsHelpers::CONFLICT).to include(exception.status_code)
        expect(codes_of(exception)).not_to be_empty
        expect([exception.message, info_of(exception).to_s].join).not_to match(PredefinedParticipantSmsHelpers::LEAKY_SQL)
        expect(campaigns.where(kind: 'invitation').count).to eq(1)
      end

      it 'allows a new invitation once the previous one is sent' do
        call_service
        campaigns.sole.update!(status: 'sent')
        expect(rejection).to be_nil
        expect(campaigns.where(kind: 'invitation').count).to eq(2)
      end

      it 'does not block a manual reminder while an invitation is in flight' do
        create_participant(intervention, sms_invitation_sent_at: 3.days.ago)
        call_service
        expect(rejection(build_params(kind: 'manual_reminder'))).to be_nil
        expect(campaigns.pluck(:kind)).to contain_exactly('invitation', 'manual_reminder')
      end
    end

    describe 'the job is enqueued after the transaction commits' do
      it 'enqueues exactly once, outside any transaction opened by the service' do
        baseline = ActiveRecord::Base.connection.open_transactions
        observed = []
        subscription = ActiveSupport::Notifications.subscribe('enqueue.active_job') do |*, payload|
          observed << { depth: ActiveRecord::Base.connection.open_transactions, job: payload[:job].class.name,
                        arguments: payload[:job].arguments }
        end
        call_service
        expect(observed.size).to eq(1)
        expect(observed.first[:depth]).to eq(baseline)
        expect(observed.first[:job]).to eq(job_class.name)
        expect(observed.first[:arguments]).to eq([campaigns.sole.id])
      ensure
        ActiveSupport::Notifications.unsubscribe(subscription)
      end
    end

    describe 'the queue is unavailable' do
      before { allow(job_class).to receive(:perform_later).and_raise(StandardError, 'queue unavailable') }

      it 'leaves the campaign scheduled and not failed' do
        begin
          call_service
        rescue NameError
          raise
        rescue StandardError
          nil
        end
        campaign = campaigns.sole
        expect(campaign.status).to eq('scheduled')
        expect(campaign.failed_count).to eq(0)
      end
    end
  end

  describe 'daily SMS cap' do
    let(:researcher) { campaign_researcher }
    let(:intervention) { create(:intervention, :published, user: researcher) }
    let(:params) do
      ActionController::Parameters.new(kind: 'invitation', body: SmsCampaignTestHelpers::CANARY_BODY, links: []).permit!
    end
    let!(:participants) { Array.new(5) { |i| campaign_participant(intervention, index: i) } }
    let(:cap_key) { SmsCampaignTestHelpers::SETTING_KEYS.fetch(:daily_cap) }

    def seed_sent_today(on_intervention, count:, sent_at: Time.current, pups: nil)
      history = create(:pdp_sms_campaign, :due_soon, intervention: on_intervention, kind: 'manual_reminder', status: 'sent',
                                                     sent_at: sent_at, scheduled_at: sent_at, recipients_count: count, accepted_count: count)
      history.update_columns(created_at: sent_at, updated_at: sent_at)
      pups ||= Array.new(count) { |i| campaign_participant(on_intervention, index: i) }
      pups.first(count).each do |user_param|
        delivery = create(:pdp_sms_delivery, campaign: history, predefined_user_parameter: user_param, status: 'sent', sent_at: sent_at)
        delivery.update_columns(created_at: sent_at, updated_at: sent_at)
      end
      history
    end

    def call_service
      described_class.call(intervention, researcher, params)
    end

    it 'refuses a campaign whose recipients alone exceed the daily cap, and creates nothing' do
      with_sms_campaign_settings(cap_key => 3) do
        error = attempt_capturing_error { call_service }

        expect(error).to be_a(ComplexException)
        expect(PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id)).to be_empty
      end
    end

    it 'accepts the same campaign when the cap is above the recipient count' do
      with_sms_campaign_settings(cap_key => 50) do
        expect { call_service }.to change { PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id).count }.by(1)
      end
    end

    it 'counts SMS already sent in the last 24 hours towards the cap' do
      seed_sent_today(intervention, count: 5, pups: participants)

      with_sms_campaign_settings(cap_key => 7) do
        expect(attempt_capturing_error { call_service }).to be_a(ComplexException)
      end
      with_sms_campaign_settings(cap_key => 50) do
        expect { call_service }.to change { PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id, status: 'scheduled').count }.by(1)
      end
    end

    it 'SMS sent more than 24 hours ago do not count towards the cap' do
      seed_sent_today(intervention, count: 5, sent_at: 25.hours.ago, pups: participants)

      with_sms_campaign_settings(cap_key => 7) do
        expect { call_service }.to change { PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id, status: 'scheduled').count }.by(1)
      end
    end

    it 'the cap is per intervention - SMS sent by another intervention without an organization do not count' do
      other_intervention = create(:intervention, :published, user: researcher)
      seed_sent_today(other_intervention, count: 5)

      with_sms_campaign_settings(cap_key => 7) do
        expect { call_service }.to change { PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id, status: 'scheduled').count }.by(1)
      end
    end

    context 'when the intervention belongs to an organization' do
      let(:organization) { create(:organization) }
      let(:sibling) { create(:intervention, :published, user: researcher) }

      before do
        intervention.update_columns(organization_id: organization.id)
        sibling.update_columns(organization_id: organization.id)
      end

      it 'SMS sent by a sibling intervention of the same organization count towards the cap' do
        seed_sent_today(sibling, count: 5)

        with_sms_campaign_settings(cap_key => 7) do
          expect(attempt_capturing_error { call_service }).to be_a(ComplexException)
          expect(PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id)).to be_empty
        end
      end

      it 'a sibling campaign created but not yet sent already counts towards the cap' do
        Array.new(5) { |i| campaign_participant(sibling, index: i) }

        with_sms_campaign_settings(cap_key => 7) do
          described_class.call(sibling, researcher, params)

          expect(attempt_capturing_error { call_service }).to be_a(ComplexException)
          expect(PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id)).to be_empty
        end
      end

      it 'the same sibling traffic does not block the campaign when the cap is high enough' do
        seed_sent_today(sibling, count: 5)

        with_sms_campaign_settings(cap_key => 50) do
          expect { call_service }.to change { PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id).count }.by(1)
        end
      end
    end

    describe 'enforcement beyond the edge: POST /sms_campaigns', type: :request do
      let(:path) { "/v1/interventions/#{intervention.id}/predefined_participants/sms_campaigns" }
      let(:request) do
        post path, params: { sms_campaign: { kind: 'invitation', body: 'CIAS_TDD_CANARY_BODY' } }, as: :json,
                   headers: researcher.create_new_auth_token
      end

      it 'accepts a request under the cap with 202 (control)' do
        seed_sent_today(intervention, count: 5, pups: participants)
        with_sms_campaign_settings(cap_key => 50) do
          request
          expect(response).to have_http_status(:accepted)
        end
      end

      it 'does not answer 202 and creates nothing once the cap is exhausted' do
        seed_sent_today(intervention, count: 5, pups: participants)
        with_sms_campaign_settings(cap_key => 7) do
          expect { request }.not_to change(PredefinedParticipants::SmsCampaign, :count)
          expect(response.status).to be_between(400, 499)
        end
      end
    end
  end
end
