# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PredefinedParticipants::SmsRecipientsQuery' do
  context 'with a campaign created per example' do
    include PredefinedParticipantSmsHelpers

    let(:intervention) { create(:intervention, :published) }
    let(:researcher) { create(:user, :researcher, :confirmed) }

    before { travel_to(frozen_now) }

    def recipients(campaign)
      PredefinedParticipants::SmsRecipientsQuery.call(campaign)
    end

    def campaign_for(kind)
      return create(:pdp_sms_campaign, intervention: intervention, kind: kind) unless kind == 'scheduled_reminder'

      parent = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent', sent_at: 3.days.ago)
      create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: parent, days_after: 3)
    end

    def eligible_for(kind, campaign, index: 0, **options)
      attrs = options.dup
      attrs[:invited_at] ||= 3.days.ago unless kind == 'invitation'
      make_participant(intervention, index: index, **attrs).tap do |pup|
        next unless kind == 'scheduled_reminder'

        create(:pdp_sms_delivery, campaign: campaign.parent_campaign, predefined_user_parameter: pup, status: 'sent')
      end
    end

    describe 'invitation scope' do
      let(:campaign) { campaign_for('invitation') }

      it 'returns an active, not yet invited participant that has a phone' do
        pup = make_participant(intervention)
        expect(recipients(campaign).to_a).to contain_exactly(pup)
      end

      it 'excludes a participant whose sms_invitation_sent_at is set while keeping a not invited one' do
        kept = make_participant(intervention, index: 0)
        make_participant(intervention, index: 1, invited_at: 1.day.ago)
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end

      it 'excludes an inactive user while keeping an active one' do
        kept = make_participant(intervention, index: 0)
        make_participant(intervention, index: 1, active: false)
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end

      it 'excludes a participant without a phone while keeping one with a phone' do
        kept = make_participant(intervention, index: 0)
        make_participant(intervention, index: 1, phone: nil)
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end

      it 'excludes a participant of another intervention while keeping one of this intervention' do
        kept = make_participant(intervention, index: 0)
        make_participant(create(:intervention, :published), index: 1)
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end

      it 'returns PredefinedUserParameter rows' do
        make_participant(intervention)
        expect(recipients(campaign).to_a).to all(be_a(PredefinedUserParameter))
      end
    end

    describe 'manual_reminder scope' do
      let(:campaign) { campaign_for('manual_reminder') }

      it 'includes an invited participant that has no user_intervention row (LEFT JOIN)' do
        pup = make_participant(intervention, invited_at: 2.days.ago)
        expect(pup.user.user_interventions).to be_empty
        expect(recipients(campaign).to_a).to contain_exactly(pup)
      end

      it 'includes in_progress, excludes completed, keeps the participant without a row' do
        without_row = make_participant(intervention, index: 0, invited_at: 2.days.ago)
        in_progress = make_participant(intervention, index: 1, invited_at: 2.days.ago)
        completed = make_participant(intervention, index: 2, invited_at: 2.days.ago)
        create(:user_intervention, user: in_progress.user, intervention: intervention, status: 'in_progress')
        create(:user_intervention, user: completed.user, intervention: intervention, status: 'completed')
        expect(recipients(campaign).to_a).to contain_exactly(without_row, in_progress)
      end

      it 'excludes a participant who was never invited while keeping an invited one' do
        invited = make_participant(intervention, index: 0, invited_at: 2.days.ago)
        make_participant(intervention, index: 1)
        expect(recipients(campaign).to_a).to contain_exactly(invited)
      end

      it 'excludes an inactive invited user while keeping an active invited one' do
        kept = make_participant(intervention, index: 0, invited_at: 2.days.ago)
        make_participant(intervention, index: 1, invited_at: 2.days.ago, active: false)
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end
    end

    describe 'minimum interval on last_reminder_sent_at' do
      %w[manual_reminder scheduled_reminder].each do |kind|
        it "#{kind} excludes a participant reminded 2 and 23 hours ago and keeps 25 hours and never" do
          campaign = campaign_for(kind)
          never = eligible_for(kind, campaign, index: 0)
          old = eligible_for(kind, campaign, index: 1, last_reminder_sent_at: 25.hours.ago)
          eligible_for(kind, campaign, index: 2, last_reminder_sent_at: 2.hours.ago)
          eligible_for(kind, campaign, index: 3, last_reminder_sent_at: 23.hours.ago)
          expect(recipients(campaign).to_a).to contain_exactly(never, old)
        end
      end
    end

    describe 'opt-out list' do
      %w[invitation manual_reminder scheduled_reminder].each do |kind|
        it "#{kind} excludes an opted-out user and includes the same user once the opt-out row is gone" do
          campaign = campaign_for(kind)
          kept = eligible_for(kind, campaign, index: 0)
          opted_out = eligible_for(kind, campaign, index: 1)
          create(:pdp_sms_opt_out, user: opted_out.user)
          expect(recipients(campaign).to_a).to contain_exactly(kept)
          SmsOptOut.where(user_id: opted_out.user_id).destroy_all
          expect(recipients(campaign).to_a).to contain_exactly(kept, opted_out)
        end
      end
    end

    describe 'numbers that cannot receive SMS' do
      %w[invitation manual_reminder scheduled_reminder].each do |kind|
        it "#{kind} excludes every valid-but-ineligible number class and keeps the eligible one" do
          campaign = campaign_for(kind)
          kept = eligible_for(kind, campaign, index: 0)
          PhoneNumberFixtures::VALID_BUT_NOT_ELIGIBLE.each_value.with_index(1) do |phone, offset|
            eligible_for(kind, campaign, index: offset, phone: phone)
          end
          expect(recipients(campaign).to_a).to contain_exactly(kept)
        end

        it "#{kind} follows phones.sms_eligible and not a Phonelib call" do
          campaign = campaign_for(kind)
          kept = eligible_for(kind, campaign, index: 0)
          flagged_off = eligible_for(kind, campaign, index: 1)
          flagged_off.user.phone.update_columns(sms_eligible: false)
          expect(recipients(campaign).to_a).to contain_exactly(kept)
          flagged_off.user.phone.update_columns(sms_eligible: true)
          expect(recipients(campaign).to_a).to contain_exactly(kept, flagged_off)
        end
      end
    end

    describe 'sms_notification flags are not a filter' do
      %w[invitation manual_reminder scheduled_reminder].each do |kind|
        it "#{kind} includes participants with both sms_notification flags off and on" do
          campaign = campaign_for(kind)
          pup_off = eligible_for(kind, campaign, index: 0, sms_notification: false)
          pup_on = eligible_for(kind, campaign, index: 1, sms_notification: true)
          pup_off.user.update!(sms_notification: false)
          expect(pup_off.sms_notification).to be(false)
          expect(recipients(campaign).to_a).to contain_exactly(pup_off, pup_on)
        end
      end
    end

    describe 'phone confirmation is not a filter' do
      %w[invitation manual_reminder scheduled_reminder].each do |kind|
        it "#{kind} includes participants with confirmed false and confirmed true phones" do
          campaign = campaign_for(kind)
          unconfirmed = eligible_for(kind, campaign, index: 0, confirmed: false)
          confirmed = eligible_for(kind, campaign, index: 1, confirmed: true)
          expect(unconfirmed.user.phone.confirmed).to be(false)
          expect(confirmed.user.phone.confirmed).to be(true)
          expect(recipients(campaign).to_a).to contain_exactly(unconfirmed, confirmed)
        end
      end
    end

    describe 'participants added one by one and through bulk import' do
      let(:campaign) { campaign_for('invitation') }

      def phone_attributes(number)
        { 'iso' => 'US', 'prefix' => '+1', 'number' => number }
      end

      it 'one campaign covers both creation paths and still excludes an invited participant' do
        single_user = V1::Intervention::PredefinedParticipants::CreateService.call(
          intervention,
          ActionController::Parameters.new(first_name: 'Single', last_name: 'Path', email: 'single-path@example.test',
                                           phone_attributes: phone_attributes('2015550123')).permit!
        )
        payload = [{ 'attributes' => { 'first_name' => 'Bulk', 'last_name' => 'Path', 'email' => 'bulk-path@example.test',
                                       'phone_attributes' => phone_attributes('2015550124') },
                     'variable_answers' => {} }]
        V1::Intervention::PredefinedParticipants::BulkImportService.call(researcher, intervention, payload)
        bulk_user = User.find_by!(email: 'bulk-path@example.test')
        make_participant(intervention, index: 5, invited_at: 1.day.ago)

        expected = [single_user, bulk_user].map(&:predefined_user_parameter)
        expect(recipients(campaign).to_a).to match_array(expected)
      end
    end

    describe 'scheduled_reminder scope definition' do
      let(:campaign) { campaign_for('scheduled_reminder') }

      it 'excludes a participant who opened the link and keeps one who did not' do
        kept = eligible_for('scheduled_reminder', campaign, index: 0)
        eligible_for('scheduled_reminder', campaign, index: 1, first_opened_at: 1.day.ago)
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end

      it 'excludes a participant invited by another campaign (B) and keeps one from the parent campaign' do
        kept = eligible_for('scheduled_reminder', campaign, index: 0)
        other_campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sent')
        outsider = make_participant(intervention, index: 1, invited_at: 3.days.ago)
        create(:pdp_sms_delivery, campaign: other_campaign, predefined_user_parameter: outsider, status: 'sent')
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end

      it 'keeps a participant whose delivery in the parent campaign failed but who was invited anyway' do
        kept = eligible_for('scheduled_reminder', campaign, index: 0)
        resent = make_participant(intervention, index: 1, invited_at: 3.days.ago)
        create(:pdp_sms_delivery, campaign: campaign.parent_campaign, predefined_user_parameter: resent, status: 'failed')
        expect(recipients(campaign).to_a).to contain_exactly(kept, resent)
      end

      it 'excludes a participant of the parent campaign who was never confirmed as invited' do
        kept = eligible_for('scheduled_reminder', campaign, index: 0)
        never_invited = make_participant(intervention, index: 1, invited_at: nil)
        create(:pdp_sms_delivery, campaign: campaign.parent_campaign, predefined_user_parameter: never_invited, status: 'failed')
        expect(recipients(campaign).to_a).to contain_exactly(kept)
      end
    end

    describe 'preloading of user and phone' do
      def queries_for(count)
        local_intervention = create(:intervention, :published)
        campaign = create(:pdp_sms_campaign, intervention: local_intervention, kind: 'invitation')
        count.times { |index| make_participant(local_intervention, index: index) }
        seen = []
        queries = count_queries do
          PredefinedParticipants::SmsRecipientsQuery.call(campaign).to_a.each { |pup| seen << pup.user.phone.full_number }
        end
        [queries, seen.size]
      end

      it 'issues the same number of queries for 1 and for 5 recipients' do
        queries_for(1)
        one, one_seen = queries_for(1)
        five, five_seen = queries_for(5)
        expect([one_seen, five_seen]).to eq([1, 5])
        expect(five).to eq(one)
      end
    end
  end

  context 'with campaigns memoized per kind', type: :model do
    include ActiveSupport::Testing::TimeHelpers
    include PredefinedParticipantSmsHelpers

    around { |example| travel_to(PredefinedParticipantSmsHelpers::NOW) { example.run } }

    let(:query_class) { 'PredefinedParticipants::SmsRecipientsQuery'.constantize }
    let(:intervention) { create(:intervention, :published) }
    let(:parent) { create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent') }
    let(:campaigns) do
      {
        'invitation' => -> { create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation') },
        'manual_reminder' => -> { create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder') },
        'scheduled_reminder' => lambda {
          create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: parent)
        }
      }
    end

    def campaign_for(kind)
      @campaigns_by_kind ||= {}
      @campaigns_by_kind[kind] ||= campaigns.fetch(kind).call
    end

    def reachable(kind, **overrides)
      attrs = kind == 'invitation' ? {} : { sms_invitation_sent_at: 3.days.ago }
      pup = create_participant(intervention, **attrs, **overrides)
      create(:pdp_sms_delivery, campaign: parent, predefined_user_parameter: pup, status: 'sent') if kind == 'scheduled_reminder'
      pup
    end

    def recipient_ids(kind)
      query_class.call(campaign_for(kind)).to_a.map(&:id)
    end

    %w[invitation manual_reminder scheduled_reminder].each do |kind|
      describe "kind #{kind}" do
        let!(:included) { reachable(kind) }

        it "returns an active participant with a phone (#{kind})" do
          expect(recipient_ids(kind)).to contain_exactly(included.id)
        end

        it "excludes an inactive user and keeps the active one (#{kind})" do
          reachable(kind, active: false)
          expect(recipient_ids(kind)).to contain_exactly(included.id)
        end

        it "excludes a participant without a phone row and keeps the one with a phone (#{kind})" do
          reachable(kind, phone: nil)
          expect(recipient_ids(kind)).to contain_exactly(included.id)
        end

        it "excludes an opted-out user from #{kind} and keeps the one who is not opted out" do
          opted_out = reachable(kind)
          create(:pdp_sms_opt_out, user: opted_out.user)
          expect(recipient_ids(kind)).to contain_exactly(included.id)
        end

        {
          'a PL landline' => PhoneNumberFixtures::PL_LANDLINE,
          'a US premium-rate number' => PhoneNumberFixtures::US_PREMIUM
        }.each do |label, number|
          it "excludes #{label} from #{kind} and keeps the eligible number" do
            ineligible = reachable(kind, phone: number)
            expect(ineligible.user.phone.sms_eligible).to be(false)
            expect(recipient_ids(kind)).to contain_exactly(included.id)
          end
        end

        it "excludes a phone flagged sms_eligible false from #{kind} without calling Phonelib" do
          flagged = reachable(kind)
          flagged.user.phone.update_column(:sms_eligible, false)
          campaign = campaign_for(kind)
          expect(Phonelib).not_to receive(:valid?)
          expect(Phonelib).not_to receive(:parse)
          expect(query_class.call(campaign).to_a.map(&:id)).to contain_exactly(included.id)
        end

        it "keeps a participant whose sms_notification flags are false in #{kind}" do
          quiet = reachable(kind, sms_notification: false)
          quiet.user.update_column(:sms_notification, false)
          expect(quiet.reload.sms_notification).to be(false)
          expect(recipient_ids(kind)).to contain_exactly(included.id, quiet.id)
        end

        it "keeps a participant whose phone is unconfirmed in #{kind}" do
          unconfirmed = reachable(kind, confirmed: false)
          confirmed = reachable(kind, confirmed: true)
          expect(unconfirmed.user.phone.reload.confirmed).to be(false)
          expect(recipient_ids(kind)).to contain_exactly(included.id, unconfirmed.id, confirmed.id)
        end

        it "does not query per recipient when reading user and phone (#{kind})" do
          campaign = campaign_for(kind)
          visited = []
          visit = lambda do
            visited.clear
            query_class.call(campaign).find_each { |pup| visited << pup.user.phone.full_number }
          end
          one = count_queries(&visit)
          expect(visited.size).to eq(1)
          4.times { reachable(kind) }
          five = count_queries(&visit)
          expect(visited.size).to eq(5)
          expect(five).to eq(one)
        end
      end
    end

    describe 'invitation scope' do
      let!(:uninvited) { reachable('invitation') }

      it 'excludes a participant who already has sms_invitation_sent_at and keeps the uninvited one' do
        reachable('manual_reminder')
        expect(recipient_ids('invitation')).to contain_exactly(uninvited.id)
      end

      it 'excludes a participant of another intervention and keeps the one of this intervention' do
        create_participant(create(:intervention, :published))
        expect(recipient_ids('invitation')).to contain_exactly(uninvited.id)
      end
    end

    describe 'manual_reminder scope' do
      let!(:never_opened) { reachable('manual_reminder') }

      it 'includes an invited participant who has no user_intervention row' do
        expect(UserIntervention.where(user_id: never_opened.user_id)).to be_empty
        expect(recipient_ids('manual_reminder')).to contain_exactly(never_opened.id)
      end

      it 'includes participants whose user_intervention is not completed and excludes a completed one' do
        in_progress = reachable('manual_reminder')
        ready = reachable('manual_reminder')
        completed = reachable('manual_reminder')
        create(:user_intervention, :in_progress, user: in_progress.user, intervention: intervention)
        create(:user_intervention, :ready_to_start, user: ready.user, intervention: intervention)
        create(:user_intervention, :completed, user: completed.user, intervention: intervention)
        expect(recipient_ids('manual_reminder')).to contain_exactly(never_opened.id, in_progress.id, ready.id)
      end

      it 'excludes a participant who was not invited and keeps the invited one' do
        create_participant(intervention)
        expect(recipient_ids('manual_reminder')).to contain_exactly(never_opened.id)
      end

      it 'includes a participant last reminded more than 24 hours ago' do
        old = reachable('manual_reminder', last_reminder_sent_at: 25.hours.ago)
        expect(recipient_ids('manual_reminder')).to contain_exactly(never_opened.id, old.id)
      end
    end

    describe 'minimum interval since last_reminder_sent_at' do
      %w[manual_reminder scheduled_reminder].each do |kind|
        it "excludes a participant reminded 2 hours ago from #{kind} and keeps one reminded 25 hours ago" do
          recent = reachable(kind, last_reminder_sent_at: 2.hours.ago)
          older = reachable(kind, last_reminder_sent_at: 25.hours.ago)
          never = reachable(kind)
          expect(recipient_ids(kind)).to contain_exactly(older.id, never.id)
          expect(recipient_ids(kind)).not_to include(recent.id)
        end
      end
    end

    describe 'scheduled_reminder scope (no AC id in the matrix)' do
      let!(:waiting) { reachable('scheduled_reminder') }

      it 'excludes a participant who opened the personal link and keeps one who did not' do
        reachable('scheduled_reminder', first_opened_at: 1.day.ago)
        expect(recipient_ids('scheduled_reminder')).to contain_exactly(waiting.id)
      end

      it 'excludes a participant invited by another campaign and keeps the parent recipient' do
        other_batch = create_participant(intervention, sms_invitation_sent_at: 1.hour.ago)
        other_campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent')
        create(:pdp_sms_delivery, campaign: other_campaign, predefined_user_parameter: other_batch, status: 'sent')
        expect(recipient_ids('scheduled_reminder')).to contain_exactly(waiting.id)
      end

      it 'keeps a participant whose parent delivery failed but who carries an invitation confirmation' do
        failed = create_participant(intervention, sms_invitation_sent_at: 3.days.ago)
        create(:pdp_sms_delivery, campaign: parent, predefined_user_parameter: failed, status: 'failed')
        expect(recipient_ids('scheduled_reminder')).to contain_exactly(waiting.id, failed.id)
      end

      it 'excludes a participant of the parent campaign who carries no invitation confirmation' do
        never_invited = create_participant(intervention, sms_invitation_sent_at: nil)
        create(:pdp_sms_delivery, campaign: parent, predefined_user_parameter: never_invited, status: 'failed')
        expect(recipient_ids('scheduled_reminder')).to contain_exactly(waiting.id)
      end
    end

    describe 'participants added one by one and through bulk import' do
      let(:researcher) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention, :published, user: researcher) }

      def one_by_one
        params = ActionController::Parameters.new(first_name: 'Alice', last_name: 'Smith', email: 'ac41b-one@example.test',
                                                  phone_attributes: PhoneNumberFixtures::US_MAIN).permit!
        V1::Intervention::PredefinedParticipants::CreateService.call(intervention, params)
      end

      def bulk
        entry = { 'attributes' => { 'first_name' => 'Bob', 'last_name' => 'Jones', 'email' => 'ac41b-bulk@example.test',
                                    'phone_attributes' => PhoneNumberFixtures::US_OTHER.stringify_keys },
                  'variable_answers' => {} }
        V1::Intervention::PredefinedParticipants::BulkImportService.call(researcher, intervention, [entry])
      end

      it 'returns both in one invitation campaign and gives both a personal and a tracked slug' do
        single = one_by_one
        expect(bulk).to include(participants_created: 1, failed: 0)
        bulk_user = User.find_by!(email: 'ac41b-bulk@example.test')
        campaign = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation',
                                             body: "#{PredefinedParticipantSmsHelpers::CANARY_BODY} ::canary_link::")
        create(:pdp_campaign_sms_link, campaign: campaign, variable: 'canary_link')

        recipients = query_class.call(campaign)
        expect(recipients.to_a.map(&:user_id)).to contain_exactly(single.id, bulk_user.id)

        links = V1::PredefinedParticipants::SmsCampaigns::RenderBody.prepare_links(campaign, recipients)
        sms_link_id = campaign.sms_links.first.id
        expect(links.keys).to contain_exactly([sms_link_id, single.id], [sms_link_id, bulk_user.id])
        expect(recipients.to_a.map(&:slug)).to all(be_present)
      end
    end
  end
end
