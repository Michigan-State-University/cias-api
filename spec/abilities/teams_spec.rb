# frozen_string_literal: true

require 'cancan/matchers'

describe Team do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it { should have_abilities(:manage, described_class) }
    end

    context 'team admin' do
      let!(:users_team) { create(:team) }
      let!(:other_team) { create(:team) }
      let(:user) { build_stubbed(:user, :confirmed, :team_admin, team_id: users_team.id) }

      it 'can read, edit a team, that he is admin for' do
        expect(subject).to have_abilities(
          {
            read: true, update: true, destroy: false
          },
          users_team
        )
      end

      it 'can\'t read, update, destroy other team' do
        expect(subject).to not_have_abilities(
          %i[read update destroy],
          other_team
        )
      end

      it { should not_have_abilities(:create, described_class) }
    end

    context 'researcher' do
      let(:user) { build_stubbed(:user, :confirmed, :researcher) }

      it do
        expect(subject).to not_have_abilities(
          %i[read create update destroy],
          described_class
        )
      end
    end

    context 'participant' do
      let(:user) { build_stubbed(:user, :confirmed, :participant) }

      it do
        expect(subject).to not_have_abilities(
          %i[read create update destroy],
          described_class
        )
      end
    end

    context 'guest' do
      let(:user) { build_stubbed(:user, :confirmed, :guest) }

      it do
        expect(subject).to not_have_abilities(
          %i[read create update destroy],
          described_class
        )
      end
    end
  end
end
