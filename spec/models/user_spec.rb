# frozen_string_literal: true

require 'rails_helper'

describe User, type: :model do
  it { should have_many(:team_invitations).dependent(:destroy) }

  describe 'participant' do
    subject { create(:user, :confirmed, :participant) }

    it { should be_valid }
    it { should have_many(:interventions) }
  end

  describe 'admin' do
    subject { create(:user, :confirmed, :admin) }

    it { should be_valid }
    it { should have_many(:interventions) }
  end

  describe 'team_is_present?' do
    context 'user has role team admin' do
      context 'team admin has not assigned team' do
        let(:user) { build_stubbed(:user, :team_admin, team_id: nil) }

        it 'is not valid' do
          expect(user).not_to be_valid
          expect(user.errors.messages[:roles]).to include(/Team Admin must have a team/)
        end
      end

      context 'team admin has assigned team' do
        let(:team) { create(:team) }
        let(:user) { build_stubbed(:user, :team_admin, team_id: team.id) }

        it 'is valid' do
          expect(user).to be_valid
        end
      end
    end
  end

  describe 'team_admin_already_exists?' do
    context 'user has role team admin' do
      context 'when team already has other team admin' do
        let!(:team) { create(:team, :with_team_admin) }
        let(:user) { build_stubbed(:user, :team_admin, team_id: team.id) }

        it 'is not valid' do
          expect(user).not_to be_valid
          expect(user.errors.messages[:team_id]).to include(/There should be only one Team Admin in a team. The chosen team already has Team Admin/)
        end
      end

      context 'when team does not have team admin yet' do
        let(:team) { create(:team) }
        let(:user) { build_stubbed(:user, :team_admin, team_id: team.id) }

        it 'is valid' do
          expect(user).to be_valid
        end
      end
    end
  end

  describe '#time_zone' do
    %w[America/New_York Europe/Warsaw Europe/Vienna America/Chicago America/Denver
       America/Detroit].each do |time_zone|
      context "time zone is #{time_zone}" do
        let(:user) { build_stubbed(:user, :confirmed, :researcher, time_zone: time_zone) }

        it 'user is valid with time zone' do
          expect(user).to be_valid
        end
      end
    end
  end

  context 'user has role researcher' do
    let(:user) { build_stubbed(:user, :researcher) }

    include_examples 'without team admin validations'
  end

  context 'user has role guest' do
    let(:user) { build_stubbed(:user, :guest) }

    include_examples 'without team admin validations'
  end

  context 'user has role admin' do
    let(:user) { build_stubbed(:user, :admin) }

    include_examples 'without team admin validations'
  end

  context 'user has role participant' do
    let(:user) { build_stubbed(:user, :participant) }

    include_examples 'without team admin validations'
  end
end
