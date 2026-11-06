# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::TestParticipants::PurgeService do
  subject(:purge) { described_class.call(guest.id) }

  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let_it_be(:session) do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
      create(:session, intervention: intervention)
    end
  end

  # Not `let_it_be`: the subject destroys all of it, so it cannot be memoised across examples.
  let(:guest) do
    create(:user, :confirmed, :guest).tap do |user|
      user.update!(test_run: true, test_run_intervention_id: intervention.id, test_run_marked_by_id: researcher.id)
    end
  end

  let(:user_intervention) { create(:user_intervention, user: guest, intervention: intervention) }
  # Without a `name_audio` the audit-volume examples below pass whether or not `Audio` is suppressed.
  let(:name_audio) { create(:audio, usage_counter: 1) }
  let(:user_session) do
    create(:user_session, user: guest, session: session, user_intervention: user_intervention,
                          name_audio: name_audio)
  end
  let(:answer) { create(:answer_single, user_session: user_session) }
  let(:generated_report) { create(:generated_report, user_session: user_session) }
  let(:tlfb_day) { create(:tlfb_day, user_session: user_session) }
  let(:chart_statistic) { create(:chart_statistic, user_session: user_session, user: guest) }

  let(:sms_campaign_event) { SmsCampaignEvent.create!(event_type: 'user_session_created', user_session: user_session) }

  let(:conversation) { LiveChat::Conversation.create!(intervention: intervention) }
  let(:interlocutor) { LiveChat::Interlocutor.create!(user: guest, conversation: conversation) }

  # The session must be passed explicitly — the factory builds its own and `set_derived_ids` uses `||=`,
  # so otherwise this row lands on another intervention and every assertion about it passes vacuously.
  let(:sms_plan) { create(:sms_plan, session: session) }
  let(:sms_link) { create(:sms_link, sms_plan: sms_plan, session: session) }
  let(:sms_links_user) { create(:sms_links_user, user: guest, sms_link: sms_link) }

  let(:control_participant) { create(:user, :confirmed, :participant) }
  let(:control_user_intervention) { create(:user_intervention, user: control_participant, intervention: intervention) }
  let(:control_user_session) do
    create(:user_session, user: control_participant, session: session, user_intervention: control_user_intervention)
  end
  let(:control_chart_statistic) do
    create(:chart_statistic, user_session: control_user_session, user: control_participant)
  end

  def build_test_participant_data
    [answer, generated_report, tlfb_day, chart_statistic, sms_campaign_event, interlocutor, sms_links_user]
  end

  def build_control_data
    control_chart_statistic
  end

  # Makes the destruction order a regression test: moving the ChartStatistic step fails here even if nothing raises.
  def deleted_tables
    tables = []
    collector = lambda do |_name, _start, _finish, _id, payload|
      table = payload[:sql].to_s[/\ADELETE FROM "([^"]+)"/, 1]
      tables << table if table
    end

    ActiveSupport::Notifications.subscribed(collector, 'sql.active_record') { yield }

    tables
  end

  before do
    build_test_participant_data
    build_control_data
  end

  describe 'the destruction order' do
    it 'does not raise the foreign-key violation that a naive cascade would' do
      expect { purge }.not_to raise_error
    end

    it 'deletes chart_statistics before the user_sessions they reference' do
      tables = deleted_tables { purge }

      expect(tables).to include('chart_statistics', 'user_sessions')
      expect(tables.index('chart_statistics')).to be < tables.index('user_sessions')
    end

    it 'deletes sms_campaign_events before the user_sessions they reference' do
      tables = deleted_tables { purge }

      expect(tables).to include('sms_campaign_events', 'user_sessions')
      expect(tables.index('sms_campaign_events')).to be < tables.index('user_sessions')
    end

    it 'deletes the live-chat interlocutor before the user row it blocks' do
      tables = deleted_tables { purge }

      expect(tables).to include('live_chat_interlocutors', 'users')
      expect(tables.index('live_chat_interlocutors')).to be < tables.index('users')
    end

    it 'is required because user.destroy raises on the very same fixture' do
      expect { guest.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end

    it 'deletes the user row only after every restricting association is gone' do
      tables = deleted_tables { purge }

      expect(tables).to include('users', 'user_interventions', 'user_sessions', 'live_chat_interlocutors')
      %w[user_interventions user_sessions live_chat_interlocutors].each do |blocker|
        expect(tables.index(blocker)).to be < tables.index('users')
      end
    end
  end

  describe 'the cascade' do
    it 'removes the participant and its whole subtree' do
      purge

      expect(User.where(id: guest.id)).to be_empty
      expect(UserIntervention.where(id: user_intervention.id)).to be_empty
      expect(UserSession.where(id: user_session.id)).to be_empty
      expect(Answer.where(id: answer.id)).to be_empty
      expect(GeneratedReport.where(id: generated_report.id)).to be_empty
      expect(Tlfb::Day.where(id: tlfb_day.id)).to be_empty
    end

    it 'removes the live-chat conversation the participant took part in' do
      purge

      expect(LiveChat::Conversation.where(id: conversation.id)).to be_empty
      expect(LiveChat::Interlocutor.where(id: interlocutor.id)).to be_empty
    end

    it 'clears the rows that reference user_sessions with a bare foreign key' do
      purge

      expect(SmsCampaignEvent.where(id: sms_campaign_event.id)).to be_empty
    end

    it 'clears the sms-link rows that reference the user with a bare foreign key' do
      result = purge

      expect(SmsLinksUser.where(id: sms_links_user.id)).to be_empty
      expect(result.counts[:sms_links_users]).to eq(1)
    end

    it 'reports what it destroyed' do
      result = purge

      expect(result).to be_purged
      expect(result).to be_user_destroyed
      expect(result.counts).to include(user_sessions: 1, user_interventions: 1, chart_statistics: 1)
    end
  end

  describe 'the charts' do
    it "removes the participant's contribution" do
      purge

      expect(ChartStatistic.where(id: chart_statistic.id)).to be_empty
    end

    it "leaves a real participant's contribution untouched" do
      purge

      expect(ChartStatistic.where(id: control_chart_statistic.id)).to be_present
      expect(control_chart_statistic.reload.user_id).to eq(control_participant.id)
    end

    it 'leaves the real participant and their session alone' do
      purge

      expect(User.where(id: control_participant.id)).to be_present
      expect(UserSession.where(id: control_user_session.id)).to be_present
    end
  end

  # `test_run` is user-level, but the link that sets it is per-intervention and one guest identity spans several.
  describe 'a marked guest who also filled a different intervention' do
    let_it_be(:other_intervention) { create(:intervention, status: :published, shared_to: :anyone) }
    let_it_be(:other_session) do
      RSpec::Mocks.with_temporary_scope do
        allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
        create(:session, intervention: other_intervention)
      end
    end

    let(:other_user_intervention) { create(:user_intervention, user: guest, intervention: other_intervention) }
    let(:other_user_session) do
      create(:user_session, user: guest, session: other_session, user_intervention: other_user_intervention)
    end
    let(:other_answer) { create(:answer_single, user_session: other_user_session) }
    let(:other_chart_statistic) { create(:chart_statistic, user_session: other_user_session, user: guest) }

    let(:other_conversation) { LiveChat::Conversation.create!(intervention: other_intervention) }
    let(:other_navigator) { create(:user, :confirmed, :navigator) }
    let(:other_interlocutor) { LiveChat::Interlocutor.create!(user: guest, conversation: other_conversation) }
    let(:other_navigator_interlocutor) do
      LiveChat::Interlocutor.create!(user: other_navigator, conversation: other_conversation)
    end
    let(:other_message) do
      LiveChat::Message.create!(conversation: other_conversation, live_chat_interlocutor: other_interlocutor,
                                content: 'message on the other intervention')
    end

    let(:other_sms_plan) { create(:sms_plan, session: other_session) }
    let(:other_sms_link) { create(:sms_link, sms_plan: other_sms_plan, session: other_session) }
    let(:other_sms_links_user) { create(:sms_links_user, user: guest, sms_link: other_sms_link) }

    before do
      [other_answer, other_chart_statistic, other_navigator_interlocutor, other_message, other_sms_links_user]
    end

    it "does not touch the other intervention's fills" do
      purge

      expect(UserIntervention.where(id: other_user_intervention.id)).to be_present
      expect(UserSession.where(id: other_user_session.id)).to be_present
      expect(Answer.where(id: other_answer.id)).to be_present
    end

    it "does not touch the other intervention's chart statistics" do
      purge

      expect(ChartStatistic.where(id: other_chart_statistic.id)).to be_present
      expect(other_chart_statistic.reload.user_id).to eq(guest.id)
    end

    it 'keeps the user row, because the surviving data still references it' do
      result = purge

      expect(User.where(id: guest.id)).to be_present
      expect(result).to be_purged
      expect(result).not_to be_user_destroyed
    end

    it 'releases the marker so later sweeps stop treating the guest as a candidate' do
      purge

      expect(guest.reload.test_run).to be(false)
      expect(guest.test_run_intervention_id).to be_nil
      expect(guest.purge_scheduled_at).to be_nil
    end

    it 'still removes the marked intervention data' do
      purge

      expect(UserSession.where(id: user_session.id)).to be_empty
      expect(ChartStatistic.where(id: chart_statistic.id)).to be_empty
    end

    it "leaves the other intervention's live-chat conversation and both its sides intact" do
      purge

      expect(LiveChat::Conversation.where(id: other_conversation.id)).to be_present
      expect(LiveChat::Interlocutor.where(id: other_interlocutor.id)).to be_present
      expect(LiveChat::Interlocutor.where(id: other_navigator_interlocutor.id)).to be_present
      expect(LiveChat::Message.where(id: other_message.id)).to be_present
    end

    it "leaves the other intervention's sms-link rows intact" do
      purge

      expect(SmsLinksUser.where(id: other_sms_links_user.id)).to be_present
    end
  end

  describe 'a marked guest holding an out-of-scope reference that blocks the shell' do
    let_it_be(:other_intervention) { create(:intervention, status: :published, shared_to: :anyone) }
    let_it_be(:other_session) do
      RSpec::Mocks.with_temporary_scope do
        allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
        create(:session, intervention: other_intervention)
      end
    end

    let(:other_sms_plan) { create(:sms_plan, session: other_session) }
    let(:other_sms_link) { create(:sms_link, sms_plan: other_sms_plan, session: other_session) }
    let(:other_sms_links_user) { create(:sms_links_user, user: guest, sms_link: other_sms_link) }

    before { other_sms_links_user }

    it 'completes without raising' do
      expect { purge }.not_to raise_error
    end

    it 'still destroys the marked intervention data' do
      purge

      expect(UserSession.where(id: user_session.id)).to be_empty
      expect(Answer.where(id: answer.id)).to be_empty
      expect(ChartStatistic.where(id: chart_statistic.id)).to be_empty
    end

    it 'keeps the out-of-scope sms-link row' do
      purge

      expect(SmsLinksUser.where(id: other_sms_links_user.id)).to be_present
    end

    it 'keeps the user shell and releases the marker' do
      result = purge

      expect(User.where(id: guest.id)).to be_present
      expect(result).not_to be_user_destroyed
      expect(guest.reload.test_run).to be(false)
      expect(guest.test_run_intervention_id).to be_nil
    end
  end

  describe 'refusals' do
    it 'does nothing for a participant un-marked between scheduling and execution' do
      guest.update!(test_run: false)

      result = purge

      expect(result).not_to be_purged
      expect(result.skip_reason).to eq(:not_marked)
      expect(User.where(id: guest.id)).to be_present
      expect(UserSession.where(id: user_session.id)).to be_present
    end

    it 'refuses a marked participant whose marker names no intervention' do
      guest.update_columns(test_run_intervention_id: nil)

      result = purge

      expect(result).not_to be_purged
      expect(result.skip_reason).to eq(:unscoped_marker)
      expect(UserSession.where(id: user_session.id)).to be_present
    end

    it 'is a no-op for a user that no longer exists' do
      purge

      result = described_class.call(guest.id)

      expect(result).not_to be_purged
      expect(result.skip_reason).to eq(:already_purged)
    end

    it 'does not raise when called twice' do
      purge

      expect { described_class.call(guest.id) }.not_to raise_error
    end
  end

  describe 'transactionality' do
    # The shell destroy is the only seam that fails *after* every other step, so these examples observe a
    # genuinely half-finished purge coming back. Stubbing `UserIntervention` instead fails before anything
    # was destroyed and proves almost nothing.
    before do
      allow(User).to receive(:where).and_call_original
      allow(User).to receive(:where).with(hash_including(test_run: true))
                                    .and_raise(ActiveRecord::StatementInvalid, 'forced mid-purge failure')
    end

    it 'propagates the failure' do
      expect { purge }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'leaves everything intact, including the rows destroyed before the failure' do
      expect { purge }.to raise_error(ActiveRecord::StatementInvalid)

      expect(User.where(id: guest.id)).to be_present
      expect(UserIntervention.where(id: user_intervention.id)).to be_present
      expect(UserSession.where(id: user_session.id)).to be_present
      expect(ChartStatistic.where(id: chart_statistic.id)).to be_present
      expect(SmsCampaignEvent.where(id: sms_campaign_event.id)).to be_present
      expect(LiveChat::Conversation.where(id: conversation.id)).to be_present
    end

    it 'brings back the rows destroyed by the cascade before the failure' do
      expect { purge }.to raise_error(ActiveRecord::StatementInvalid)

      expect(Answer.where(id: answer.id)).to be_present
      expect(GeneratedReport.where(id: generated_report.id)).to be_present
      expect(SmsLinksUser.where(id: sms_links_user.id)).to be_present
    end
  end

  describe 'the record it leaves behind' do
    it 'counts the rows removed by the cascade, which destroy_all never reports' do
      result = purge

      expect(result.counts).to include(answers: 1, generated_reports: 1, tlfb_days: 1)
    end

    it 'logs the purge at warn with the researcher accountable for the marker' do
      allow(Rails.logger).to receive(:warn)

      purge

      expect(Rails.logger).to have_received(:warn).with(
        a_string_including("user_id=#{guest.id}", "intervention_id=#{intervention.id}",
                           "marked_by_id=#{researcher.id}")
      )
    end

    it 'logs the reason a purge was refused' do
      guest.update!(test_run: false)
      allow(Rails.logger).to receive(:warn)

      purge

      expect(Rails.logger).to have_received(:warn).with(a_string_including('reason=not_marked'))
    end

    it 'puts no participant PHI in the log line' do
      messages = []
      allow(Rails.logger).to receive(:warn) { |msg| messages << msg }

      purge

      expect(messages.join("\n")).not_to include(guest.email, guest.first_name, guest.last_name)
    end
  end

  describe 'audit volume' do
    it 'writes no audit rows for the destroyed data' do
      expect { purge }.not_to change(Audited::Audit, :count)
    end

    it 'writes no paper-trail versions for the destroyed data' do
      expect { purge }.not_to change(PaperTrail::Version, :count)
    end

    it 'leaves auditing on for everything else afterwards' do
      purge

      expect { create(:user, :confirmed, :participant) }.to change(Audited::Audit, :count)
    end
  end
end
