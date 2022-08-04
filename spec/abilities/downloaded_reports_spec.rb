# frozen_string_literal: true

require 'cancan/matchers'

describe DownloadedReport do
  let_it_be(:team1) { create(:team) }
  let_it_be(:team2) { create(:team) }
  let_it_be(:team3) { create(:team, team_admin: team1.team_admin) }
  let_it_be(:team1_researcher) { create(:user, :confirmed, :researcher, team_id: team1.id) }
  let_it_be(:team2_researcher) { create(:user, :confirmed, :researcher, team_id: team2.id) }
  let_it_be(:team3_researcher) { create(:user, :confirmed, :researcher, team_id: team3.id) }
  let_it_be(:team1_intervention1) { create(:intervention, user_id: team1.team_admin.id) }
  let_it_be(:team1_intervention2) { create(:intervention, user_id: team1_researcher.id) }
  let_it_be(:team2_intervention1) { create(:intervention, user_id: team2.team_admin.id) }
  let_it_be(:team2_intervention2) { create(:intervention, user_id: team2_researcher.id) }
  let_it_be(:team3_intervention1) { create(:intervention, user_id: team3_researcher.id) }

  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      team1_session1 = create(:session, intervention: team1_intervention1)
      team1_session2 = create(:session, intervention: team1_intervention2)
      team2_session1 = create(:session, intervention: team2_intervention1)
      team2_session2 = create(:session, intervention: team2_intervention2)
      team3_session1 = create(:session, intervention: team3_intervention1)

      team1_user_session1 = create(:user_session, session: team1_session1)
      team1_user_session2 = create(:user_session, session: team1_session2)
      team2_user_session1 = create(:user_session, session: team2_session1)
      team2_user_session2 = create(:user_session, session: team2_session2)
      team3_user_session1 = create(:user_session, session: team3_session1)

      @team1_generated_report1 = create(:generated_report, user_session: team1_user_session1)
      @team1_generated_report2 = create(:generated_report, user_session: team1_user_session2)
      @team2_generated_report1 = create(:generated_report, user_session: team2_user_session1)
      @team2_generated_report2 = create(:generated_report, user_session: team2_user_session2)
      @team3_generated_report1 = create(:generated_report, user_session: team3_user_session1)
    end
  end

  let(:team1_downloaded_report1) { create(:downloaded_report, generated_report: @team1_generated_report1, user: user) }
  let(:team1_downloaded_report2) { create(:downloaded_report, generated_report: @team1_generated_report2, user: user) }
  let(:team2_downloaded_report1) { create(:downloaded_report, generated_report: @team2_generated_report1, user: user) }
  let(:team2_downloaded_report2) { create(:downloaded_report, generated_report: @team2_generated_report2, user: user) }
  let(:team3_downloaded_report1) { create(:downloaded_report, generated_report: @team3_generated_report1, user: user) }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can mark as downloaded report generated for the user session for his team member session' do
        expect(subject).to have_abilities({ create: true }, team1_downloaded_report2)
        expect(subject).to have_abilities({ create: true }, team3_downloaded_report1)
      end

      it 'can mark his generated report' do
        expect(subject).to have_abilities({ create: true }, team1_downloaded_report1)
      end

      it 'can\'t mark generated report for the user\'s session, when session belongs to the researcher from another team' do
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
      end
    end

    context 'researcher' do
      let(:user) { team1_researcher }

      it 'can mark generated report for the session that belongs to him' do
        expect(subject).to have_abilities({ create: true }, team1_downloaded_report2)
      end

      it 'can\'t mark generated report for the sessions that belong to other researchers' do
        expect(subject).to have_abilities({ create: false }, team1_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
      end
    end

    context 'participant' do
      let(:user) { create(:user, :confirmed, :participant) }
      let!(:user_session) { create(:user_session, user: user) }
      let!(:third_party_report) do
        create(:generated_report, :third_party, user_session: user_session)
      end
      let!(:not_shown_participant_report) do
        create(:generated_report, :participant, user_session: user_session)
      end
      let!(:shown_participant_report) do
        create(:generated_report, :participant, participant_id: user.id, user_session: user_session)
      end

      let!(:third_party_report_downloaded) do
        create(:downloaded_report, generated_report: third_party_report, user: user)
      end
      let!(:not_shown_participant_report_downloaded) do
        create(:downloaded_report, generated_report: not_shown_participant_report, user: user)
      end
      let!(:shown_participant_report_downloaded) do
        create(:downloaded_report, generated_report: shown_participant_report, user: user)
      end

      it 'can mark only his report if the report kind is \'participant\' and report is shown to participant' do
        expect(subject).to have_abilities({ create: true }, shown_participant_report_downloaded)

        expect(subject).to have_abilities({ create: false }, team1_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, third_party_report_downloaded)
        expect(subject).to have_abilities({ create: false }, not_shown_participant_report_downloaded)
      end
    end

    context 'third party' do
      let(:user) { create(:user, :confirmed, :third_party) }
      let!(:third_party_report) do
        create(:generated_report, :third_party, third_party_id: user.id)
      end
      let!(:participant_report) do
        create(:generated_report, :participant, :shared_to_third_party)
      end
      let!(:other_third_party_report) do
        create(:generated_report, :third_party, :shared_to_third_party)
      end

      let!(:third_party_report_downloaded) do
        create(:downloaded_report, generated_report: third_party_report, user: user)
      end
      let!(:participant_report_downloaded) do
        create(:downloaded_report, generated_report: participant_report, user: user)
      end
      let!(:other_third_party_report_downloaded) do
        create(:downloaded_report, generated_report: other_third_party_report, user: user)
      end

      it 'can mark only his report if the report kind is \'third_party\' and report is shared with him' do
        expect(subject).to have_abilities({ create: true }, third_party_report_downloaded)

        expect(subject).to have_abilities({ create: false }, team1_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, team2_downloaded_report1)
        expect(subject).to have_abilities({ create: false }, other_third_party_report_downloaded)
        expect(subject).to have_abilities({ create: false }, participant_report_downloaded)
      end
    end
  end
end
