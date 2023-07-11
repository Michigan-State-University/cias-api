# frozen_string_literal: true

require 'cancan/matchers'

describe UserSession do
  let_it_be(:team1) { create(:team) }
  let_it_be(:team2) { create(:team) }
  let_it_be(:team1_researcher) { create(:user, :confirmed, :researcher, team_id: team1.id) }
  let_it_be(:team2_researcher) { create(:user, :confirmed, :researcher, team_id: team2.id) }
  let_it_be(:team1_intervention1) { create(:intervention, user_id: team1_researcher.id) }
  let_it_be(:team1_intervention2) { create(:intervention, user_id: team1.team_admin.id) }
  let_it_be(:team2_intervention1) { create(:intervention, user_id: team2_researcher.id) }
  let_it_be(:team2_intervention2) { create(:intervention, user_id: team2.team_admin.id) }

  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      team1_session1 = create(:session, intervention: team1_intervention1)
      team1_session2 = create(:session, intervention: team1_intervention2)
      team2_session1 = create(:session, intervention: team2_intervention1)
      team2_session2 = create(:session, intervention: team2_intervention2)

      @team1_user_session1 = create(:user_session, session: team1_session1)
      @team1_user_session2 = create(:user_session, session: team1_session2)
      @team2_user_session1 = create(:user_session, session: team2_session1)
      @team2_user_session2 = create(:user_session, session: team2_session2)
    end
  end

  let(:team1_user_session1) { @team1_user_session1 }
  let(:team1_user_session2) { @team1_user_session2 }
  let(:team2_user_session1) { @team2_user_session1 }
  let(:team2_user_session2) { @team2_user_session2 }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'collaborator' do
      let(:collaborator) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention) }
      let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, view: true) }
      let!(:user_session) { create(:user_session, session: create(:session, intervention: intervention)) }
      let(:user) { collaborator }

      it do
        expect(subject).to have_abilities({ read: false }, user_session)
      end

      context 'with edit access' do
        let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, data_access: true) }

        it do
          expect(subject).to have_abilities({ manage: true }, user_session)
        end
      end
    end

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can manage user_sessions of the user belonging to his team' do
        expect(subject).to have_abilities({ manage: true }, team1_user_session1)
      end

      it 'can manage his user_sessions' do
        expect(subject).to have_abilities({ manage: true }, team1_user_session2)
      end

      it 'can\'t manage user_sessions of users from another team' do
        expect(subject).to have_abilities({ manage: false }, team2_user_session1)
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'can access all user_sessions' do
        expect(subject).to include(
          team1_user_session1, team1_user_session2, team2_user_session1, team2_user_session2
        )
      end
    end

    context 'team1 - team_admin' do
      let!(:user) { team1.team_admin }

      it 'can access only user_sessions from his team' do
        expect(subject).to include(team1_user_session1, team1_user_session2).and \
          not_include(team2_user_session1, team2_user_session2)
      end
    end

    context 'team2 - team_admin' do
      let!(:user) { team2.team_admin }

      it 'can access only user_sessions from his team' do
        expect(subject).to include(team2_user_session1, team2_user_session2).and \
          not_include(team1_user_session1, team1_user_session2)
      end
    end

    context 'team1 - researcher' do
      let!(:user) { team1_researcher }

      it 'can access only his user_sessions' do
        expect(subject).to include(team1_user_session1).and \
          not_include(team1_user_session2, team2_user_session1, team2_user_session2)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'can\'t access any of the teams user_sessions' do
        expect(subject).not_to include(
          team1_user_session1, team1_user_session2, team2_user_session1, team2_user_session2
        )
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'can\'t access any of the teams user_sessions' do
        expect(subject).not_to include(
          team1_user_session1, team1_user_session2, team2_user_session1, team2_user_session2
        )
      end
    end
  end
end
