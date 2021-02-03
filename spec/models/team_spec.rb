# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  it { should have_many(:users) }
  it { should have_one(:team_admin) }

  describe '#team_admin' do
    let(:team) { create(:team) }
    let!(:researcher) { create(:user, :researcher, team_id: team.id) }
    let!(:team_admin) { create(:user, :team_admin, team_id: team.id) }

    it 'returns team admin from team' do
      expect(team.team_admin).to eq team_admin
    end
  end

  describe '#name' do
    context 'name is unique' do
      let(:team) { build_stubbed(:team) }

      it 'team is valid' do
        expect(team).to be_valid
      end
    end

    context 'name is not unique' do
      let!(:existing_team) { create(:team) }
      let(:team) { build_stubbed(:team, name: existing_team.name) }

      it 'team is invalid' do
        expect(team).not_to be_valid
        expect(team.errors.messages[:name]).to include(/has already been taken/)
      end
    end
  end
end
