# frozen_string_literal: true

require 'cancan/matchers'

describe Intervention do
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
  let_it_be(:collaborator) { create(:user, :researcher, :confirmed) }

  let_it_be(:organization1) { create(:organization) }
  let_it_be(:organization2) { create(:organization) }

  let_it_be(:intervention_with_organization1) { create(:intervention, organization_id: organization1.id) }
  let_it_be(:intervention_with_organization2) { create(:intervention, organization_id: organization2.id) }
  let(:intervention) { create(:intervention) }

  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'team admin' do
      let(:user) { team1.team_admin }

      it 'can manage intervention of the user belonging to his team' do
        expect(subject).to have_abilities({ manage: true }, team1_intervention1)
        expect(subject).to have_abilities({ manage: true }, team3_intervention1)
      end

      it 'can manage his intervention' do
        expect(subject).to have_abilities({ manage: true }, team1_intervention2)
      end

      it 'can\'t manage intervention of users from another team' do
        expect(subject).to have_abilities({ manage: false }, team2_intervention1)
      end

      it 'can\'t manage any intervention' do
        expect(subject).to have_abilities({ manage: false }, described_class.new)
      end
    end

    context 'collaborator with view access' do
      let!(:intervention) { create(:intervention, collaborators: [create(:collaborator, user: collaborator)]) }
      let(:user) { collaborator }

      it 'can only view intervention' do
        expect(subject).to have_abilities({ read: true }, intervention)
      end

      it 'cannot other action' do
        expect(subject).to not_have_abilities(%i[update destroy], intervention)
      end
    end

    context 'collaborator with edit access' do
      let!(:intervention) { create(:intervention, collaborators: [create(:collaborator, user: collaborator, edit: true)]) }
      let(:user) { collaborator }

      it 'can only view intervention' do
        expect(subject).to have_abilities(%i[read create update delete add_logo], intervention)
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
          team1_intervention1, team1_intervention2, team2_intervention1, team2_intervention2,
          intervention_with_organization1, intervention_with_organization2
        )
      end
    end

    context 'collaborator' do
      let!(:intervention) { create(:intervention, collaborators: [create(:collaborator, user: collaborator)]) }
      let(:user) { collaborator }

      it 'can access interventions when is a collaborator' do
        expect(subject).to include(intervention)
      end
    end

    context 'team1 - team_admin' do
      let!(:user) { team1.team_admin }

      it 'can access only interventions from his team' do
        expect(subject).to include(team1_intervention1, team1_intervention2).and \
          not_include(team2_intervention1, team2_intervention2)
      end
    end

    context 'team2 - team_admin' do
      let!(:user) { team2.team_admin }

      it 'can access only interventions from his team' do
        expect(subject).to include(team2_intervention1, team2_intervention2).and \
          not_include(team1_intervention1, team1_intervention2)
      end
    end

    context 'team1 - researcher' do
      let!(:user) { team1_researcher }

      it 'can access only his intervention' do
        expect(subject).to include(team1_intervention2).and \
          not_include(team1_intervention1, team2_intervention1, team2_intervention2)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'can\'t access any intervention' do
        expect(subject).not_to include(
          team1_intervention1, team1_intervention2, team2_intervention1, team2_intervention2
        )
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'can\'t access any intervention' do
        expect(subject).not_to include(
          team1_intervention1, team1_intervention2, team2_intervention1, team2_intervention2
        )
      end
    end

    context 'preview_session' do
      let!(:published_intervention) { create(:intervention, :published) }
      let!(:draft_intervention) { create(:intervention) }
      let!(:preview_session) { create(:session, intervention: draft_intervention) }

      let!(:user) { create(:user, :confirmed, :preview_session, preview_session_id: preview_session.id) }

      it 'can access only for draft intervention created for the preview session' do
        expect(subject).to include(draft_intervention)
        expect(subject).not_to include(published_intervention)
      end
    end

    context 'e-intervention admin' do
      let!(:user) { create(:user, :confirmed, :e_intervention_admin, organizable: organization1) }

      it 'can access only for interventions of organization where user is administrator' do
        expect(subject).to include(intervention_with_organization1)
        expect(subject).not_to include(intervention_with_organization2)
      end
    end
  end
end
