# frozen_string_literal: true

require 'cancan/matchers'

describe Session do
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
  let_it_be(:team3_intervention1) { create(:intervention, user_id: team3.team_admin.id) }
  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      @team1_session1 = create(:session, intervention: team1_intervention1)
      @team1_session2 = create(:session, intervention: team1_intervention2)
      @team2_session1 = create(:session, intervention: team2_intervention1)
      @team2_session2 = create(:session, intervention: team2_intervention2)
      @team3_session1 = create(:session, intervention: team3_intervention1)
    end
  end

  let(:team1_session1) { @team1_session1 }
  let(:team1_session2) { @team1_session2 }
  let(:team2_session1) { @team2_session1 }
  let(:team2_session2) { @team2_session2 }
  let(:team3_session1) { @team3_session1 }

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
      let!(:resource) { create(:session, intervention: intervention) }
      let(:user) { collaborator }

      it_behaves_like 'collaborator has expected access to resource'
    end

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can manage session of the user belonging to his team' do
        expect(subject).to have_abilities({ manage: true }, team1_session1)
        expect(subject).to have_abilities({ manage: true }, team3_session1)
      end

      it 'can manage his session' do
        expect(subject).to have_abilities({ manage: true }, team1_session2)
      end

      it 'can\'t manage session of users from another team' do
        expect(subject).to have_abilities({ manage: false }, team2_session1)
      end
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'can access all interventions' do
        expect(subject).to include(
          team1_session1, team1_session2, team2_session1, team2_session2
        )
      end
    end

    context 'collaborator' do
      let(:collaborator) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention) }
      let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, view: true) }
      let!(:session) { create(:session, intervention: intervention) }
      let(:user) { collaborator }

      it do
        expect(subject).to include(session).and not_include(
          team1_session1, team1_session2, team2_session1, team2_session2
        )
      end
    end

    context 'team1 - team_admin' do
      let!(:user) { team1.team_admin }

      it 'can access only interventions from his team' do
        expect(subject).to include(team1_session1, team1_session2, team3_session1).and \
          not_include(team2_session1, team2_session2)
      end
    end

    context 'team2 - team_admin' do
      let!(:user) { team2.team_admin }

      it 'can access only interventions from his team' do
        expect(subject).to include(team2_session1, team2_session2).and \
          not_include(team1_session1, team1_session2)
      end
    end

    context 'team1 - researcher' do
      let!(:user) { team1_researcher }

      it 'can access only his intervention' do
        expect(subject).to include(team1_session2).and \
          not_include(team1_session1, team2_session1, team2_session2)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'can\'t access any intervention' do
        expect(subject).not_to include(
          team1_session1, team1_session2, team2_session1, team2_session2
        )
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'can\'t access any intervention' do
        expect(subject).not_to include(
          team1_session1, team1_session2, team2_session1, team2_session2
        )
      end
    end

    context 'preview_session' do
      let!(:user) { create(:user, :confirmed, :preview_session, preview_session_id: team1_session1.id) }

      it 'can access only for preview session created for preview user' do
        expect(subject).not_to include(team1_session2, team2_session1, team2_session2)
        expect(subject).to include(team1_session1)
      end
    end
  end
end
