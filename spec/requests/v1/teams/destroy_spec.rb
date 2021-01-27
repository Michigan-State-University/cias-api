# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/teams/:id', type: :request do
  let(:request) { delete v1_team_path(team_id), headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:team) { create :team }
  let(:team_id) { team.id }

  context 'when team with given id exists' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'destroys a team' do
      expect { request }.to change(Team, :count).by(-1)
    end
  end

  context 'when team with given id does not exist' do
    let(:team_id) { 'non-existing' }

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end

    it 'does not create a new team' do
      expect { request }.not_to change(Team, :count)
    end
  end
end
