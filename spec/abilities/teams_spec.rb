# frozen_string_literal: true

require 'cancan/matchers'

describe Team do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    shared_examples 'not authorized for any team' do
      it 'can\'t read, create, update, destroy, invite_researcher, change_team_admin any team' do
        expect(subject).to not_have_abilities(
          %i[read create update destroy invite_researcher change_team_admin],
          described_class
        )
      end
    end

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'team admin' do
      let!(:users_team) { create(:team) }
      let!(:users_team2) { create(:team, team_admin: users_team.team_admin) }
      let!(:other_team) { create(:team) }
      let(:user) { users_team.team_admin }

      it 'can read, edit, invite_researcher, change_team_admin for team that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true, update: true, destroy: false, invite_researcher: true, change_team_admin: false
          },
          users_team
        )
        expect(subject).to have_abilities(
          {
            read: true, update: true, destroy: false, invite_researcher: true, change_team_admin: false
          },
          users_team2
        )
      end

      it 'can\'t read, update, destroy, invite_researcher, change_team_admin other team' do
        expect(subject).to not_have_abilities(
          %i[read update destroy invite_researcher change_team_admin],
          other_team
        )
      end

      it { should not_have_abilities(:create, described_class) }
    end

    context 'researcher' do
      let(:user) { build_stubbed(:user, :confirmed, :researcher) }

      it_behaves_like 'not authorized for any team'
    end

    context 'participant' do
      let(:user) { build_stubbed(:user, :confirmed, :participant) }

      it_behaves_like 'not authorized for any team'
    end

    context 'guest' do
      let(:user) { build_stubbed(:user, :confirmed, :guest) }

      it_behaves_like 'not authorized for any team'
    end
  end

  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }
      let!(:team1) { create(:team, created_at: Time.zone.now - 10) }
      let!(:team2) { create(:team, created_at: Time.zone.now - 5) }
      let!(:team3) { create(:team) }
      let(:ordered_team_names) { [team3.name, team2.name, team1.name] }

      it 'return all teams' do
        expect(subject).to include(team1, team2, team3)
      end

      it 'all teams are returned with proper order' do
        expect(subject.pluck(:name)).to eq(ordered_team_names)
      end
    end

    context 'team_admin' do
      let!(:users_team) { create(:team) }
      let!(:team_admin) { users_team.team_admin }
      let!(:users_team2) { create(:team, team_admin: team_admin) }
      let!(:other_team) { create(:team) }
      let!(:user) { team_admin }

      it 'return all team_admin\'s teams' do
        expect(subject).to include(users_team, users_team2).and \
          not_include(other_team)
      end
    end
  end
end
