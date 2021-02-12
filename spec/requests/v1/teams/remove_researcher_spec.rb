# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/teams/:team_id/remove_researcher', type: :request do
  let(:request) { delete v1_team_remove_researcher_path(team_id: team.id), params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:team) { create :team, :with_team_admin }

  context 'when params are valid' do
    let(:params) do
      {
        user_id: team_user.id
      }
    end

    context 'user is team researcher' do
      let(:team_user) { create(:user, :confirmed, :researcher, team_id: team.id) }

      it 'removes reseacher from the team' do
        expect { request }.to change { team_user.reload.team_id }.from(team.id).to(nil)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'user is team admin' do
      let(:team_user) { team.team_admin }

      it 'team admin is not removed from the team' do
        expect { request }.not_to change { user.reload.team_id }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'when params are invalid' do
    let(:params) do
      {
        user_id: ''
      }
    end

    it 'returns bad request status' do
      request
      expect(response).to have_http_status(:bad_request)
    end
  end
end
