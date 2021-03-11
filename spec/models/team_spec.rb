# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  it { should have_many(:users) }
  it { should belong_to(:team_admin) }
  it { should have_many(:team_invitations).dependent(:destroy) }

  describe '#name' do
    context 'name is unique' do
      let(:team) { build(:team) }

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
