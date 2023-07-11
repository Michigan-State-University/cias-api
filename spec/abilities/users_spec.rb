# frozen_string_literal: true

require 'cancan/matchers'

describe User do
  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    let_it_be(:team1) { create(:team) }
    let_it_be(:team2) { create(:team) }

    let_it_be(:team_1_user) { create(:user, :confirmed, :researcher, team_id: team1.id) }
    let_it_be(:team_2_user) { create(:user, :confirmed, :researcher, team_id: team2.id) }
    let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
    let_it_be(:participant) { create(:user, :confirmed, :participant) }
    let_it_be(:guest) { create(:user, :confirmed, :guest) }
    let_it_be(:admin) { create(:user, :confirmed, :admin) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'return all users' do
        expect(subject).to include(team_1_user, team_2_user, researcher, participant, guest, user)
      end
    end

    context 'collaborator' do
      let(:intervention1) { create(:intervention, :with_collaborators_with_data_access) }
      let(:intervention2) { create(:intervention, user: user) }
      let!(:user_intervention1) { create(:user_intervention, user: participant, intervention: intervention1) }
      let!(:user_intervention2) { create(:user_intervention, user: participant2, intervention: intervention2) }
      let(:participant2) { create(:user, :participant, :confirmed) }
      let!(:user) { intervention1.collaborators.first.user }

      it 'return all participants who answered on his own intervention or shared with him with data access' do
        expect(subject).to include(participant, participant2).and not_include(team_1_user, team_2_user, researcher, guest)
      end
    end

    context 'team_admin' do
      let(:user) { team1.team_admin }
      let!(:team3) { create(:team, team_admin: user) }
      let!(:team3_member) { create(:user, :confirmed, team_id: team3.id) }

      it 'return all users from team_admin\'s teams' do
        expect(subject).to include(team_1_user, team3_member, user).and \
          not_include(team_2_user, researcher, participant, guest)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'return all users from team_admin\'s team' do
        expect(subject).to include(user).and \
          not_include(team_1_user, team_2_user, researcher, participant, guest)
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'return all users from team_admin\'s team' do
        expect(subject).to include(user).and \
          not_include(team_1_user, team_2_user, researcher, participant, guest)
      end
    end
  end
end
