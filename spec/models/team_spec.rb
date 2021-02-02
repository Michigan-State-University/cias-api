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
end
