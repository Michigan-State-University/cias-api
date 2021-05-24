# frozen_string_literal: true

require 'cancan/matchers'

describe GeneratedReport do
  let_it_be(:admin) { create(:user, :confirmed, :admin) }
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
  let_it_be(:admin_intervention) { create(:intervention, user_id: admin.id) }

  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      team1_session1 = create(:session, intervention: team1_intervention1)
      team1_session2 = create(:session, intervention: team1_intervention2)
      team2_session1 = create(:session, intervention: team2_intervention1)
      team2_session2 = create(:session, intervention: team2_intervention2)
      team3_session1 = create(:session, intervention: team3_intervention1)
      admin_session = create(:session, intervention: admin_intervention)

      team1_user_session1 = create(:user_session, session: team1_session1)
      team1_user_session2 = create(:user_session, session: team1_session2)
      team2_user_session1 = create(:user_session, session: team2_session1)
      team2_user_session2 = create(:user_session, session: team2_session2)
      team3_user_session1 = create(:user_session, session: team3_session1)
      admin_user_session = create(:user_session, session: admin_session)

      @team1_generated_report1 = create(:generated_report, user_session: team1_user_session1)
      @team1_generated_report2 = create(:generated_report, user_session: team1_user_session2)
      @team2_generated_report1 = create(:generated_report, user_session: team2_user_session1)
      @team2_generated_report2 = create(:generated_report, user_session: team2_user_session2)
      @team3_generated_report1 = create(:generated_report, user_session: team3_user_session1)
      @admin_generated_report = create(:generated_report, user_session: admin_user_session)
    end
  end

  let(:team1_generated_report1) { @team1_generated_report1 }
  let(:team1_generated_report2) { @team1_generated_report2 }
  let(:team2_generated_report1) { @team2_generated_report1 }
  let(:team2_generated_report2) { @team2_generated_report2 }
  let(:team3_generated_report1) { @team3_generated_report1 }
  let(:admin_generated_report) { @admin_generated_report }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can read report generated for the user session for his team member session' do
        expect(subject).to have_abilities({ read: true, manage: false }, team1_generated_report2)
        expect(subject).to have_abilities({ read: true, manage: false }, team3_generated_report1)
      end

      it 'can read his generated report' do
        expect(subject).to have_abilities({ read: true, manage: false }, team1_generated_report1)
      end

      it 'can\'t read generated report for the user\'s session, when session belongs to the researcher from another team' do
        expect(subject).to have_abilities({ read: false, manage: false }, team2_generated_report1)
      end
    end

    context 'researcher' do
      let(:user) { team1_researcher }

      it 'can read generated report for the session that belongs to him' do
        expect(subject).to have_abilities({ read: true }, team1_generated_report2)
      end

      it 'can\'t read generated report for the sessions that belong to other researchers' do
        expect(subject).to have_abilities({ read: false }, team1_generated_report1)
        expect(subject).to have_abilities({ read: false }, team2_generated_report1)
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

      it 'can read only his report if the report kind is \'participant\' and report is shown to participant' do
        expect(subject).to have_abilities({ read: true }, shown_participant_report)

        expect(subject).to have_abilities({ read: false }, team1_generated_report1)
        expect(subject).to have_abilities({ read: false }, team2_generated_report1)
        expect(subject).to have_abilities({ read: false }, third_party_report)
        expect(subject).to have_abilities({ read: false }, not_shown_participant_report)
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

      it 'can read only his report if the report kind is \'third_party\' and report is shared with him' do
        expect(subject).to have_abilities({ read: true }, third_party_report)

        expect(subject).to have_abilities({ read: false }, team1_generated_report1)
        expect(subject).to have_abilities({ read: false }, team2_generated_report1)
        expect(subject).to have_abilities({ read: false }, other_third_party_report)
        expect(subject).to have_abilities({ read: false }, participant_report)
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { admin }

      it 'can access only reports generated in his interventions' do
        expect(subject).to include(admin_generated_report).and \
          not_include(team1_generated_report1, team1_generated_report2, team3_generated_report1, team2_generated_report1, team2_generated_report2)
      end
    end

    context 'team1 - team_admin' do
      let!(:user) { team1.team_admin }

      it 'can access only generated reports of the sessions available for team admin' do
        expect(subject).to include(team1_generated_report1, team1_generated_report2, team3_generated_report1).and \
          not_include(team2_generated_report1, team2_generated_report2)
      end
    end

    context 'team2 - team_admin' do
      let!(:user) { team2.team_admin }

      it 'can access only generated reports of the sessions available for team admin' do
        expect(subject).to include(team2_generated_report1, team2_generated_report2).and \
          not_include(team1_generated_report1, team1_generated_report2)
      end
    end

    context 'team1 - researcher' do
      let!(:user) { team1_researcher }

      it 'can access only reports generated for his session' do
        expect(subject).to include(team1_generated_report2).and \
          not_include(team1_generated_report1, team2_generated_report1, team2_generated_report2)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }
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

      it 'can access only reports generated for his user session and report kind is \'participant\' and report is shown to participant' do
        expect(subject).to include(shown_participant_report).and \
          not_include(team1_generated_report1, team1_generated_report2, team2_generated_report1,
                      team2_generated_report2, third_party_report, not_shown_participant_report)
      end
    end

    context 'third_party' do
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

      it 'can access only reports generated for his user session and report kind is \'participant\' and report is shown to participant' do
        expect(subject).to include(third_party_report).and \
          not_include(team1_generated_report1, team1_generated_report2, team2_generated_report1,
                      team2_generated_report2, other_third_party_report, participant_report)
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'can\'t access generated reports' do
        expect(subject).not_to include(
          team1_generated_report1, team1_generated_report2, team2_generated_report1, team2_generated_report2
        )
      end
    end
  end
end
