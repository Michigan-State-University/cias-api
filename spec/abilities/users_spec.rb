# frozen_string_literal: true

require 'cancan/matchers'

describe User do
  describe '#accessible_by' do
    subject { described_class.accessible_by(ability) }

    let(:ability) { Ability.new(user) }

    before do
      @team1 = create(:team)
      team2 = create(:team)

      @team_1_user = create(:user, :confirmed, :researcher, team_id: @team1.id)
      @team_2_user = create(:user, :confirmed, :researcher, team_id: team2.id)
      @researcher  = create(:user, :confirmed, :researcher)
      @participant = create(:user, :confirmed, :participant)
      @guest       = create(:user, :confirmed, :guest)
      @admin       = create(:user, :confirmed, :admin)
    end

    after :all do
      User.destroy_all
      Team.destroy_all
    end

    context 'admin' do
      let!(:user) { create(:user, :confirmed, :admin) }

      it 'return all users' do
        expect(subject).to include(@team_1_user, @team_2_user, @researcher, @participant, @guest, user)
      end
    end

    context 'team_admin' do
      let!(:user) { create(:user, :confirmed, :team_admin, team_id: @team1.id) }

      it 'return all users from team_admin\'s team' do
        expect(subject).to include(@team_1_user, user).and \
          not_include(@team_2_user, @researcher, @participant, @guest)
      end
    end

    context 'participant' do
      let!(:user) { create(:user, :confirmed, :participant) }

      it 'return all users from team_admin\'s team' do
        expect(subject).to include(user).and \
          not_include(@team_1_user, @team_2_user, @researcher, @participant, @guest)
      end
    end

    context 'guest' do
      let!(:user) { create(:user, :confirmed, :guest) }

      it 'return all users from team_admin\'s team' do
        expect(subject).to include(user).and \
          not_include(@team_1_user, @team_2_user, @researcher, @participant, @guest)
      end
    end
  end
end
