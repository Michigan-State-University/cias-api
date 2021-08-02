# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/teams', type: :request do
  let(:request) { post v1_teams_path, params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid, new team admin is researcher' do
    let(:new_team_admin) { create(:user, :confirmed, :researcher) }
    let(:params) do
      {
        team: {
          name: 'Best Team',
          user_id: new_team_admin.id
        }
      }
    end
    let(:new_team) { Team.order(:created_at).last }

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new team with proper name, sets researcher as team admin' do
      expect { request }.to change(Team, :count).by(1)

      expect(new_team).to have_attributes(
        name: 'Best Team',
        team_admin_id: new_team_admin.id
      )
      expect(new_team_admin.reload).to have_attributes(
        roles: ['team_admin'],
        team_id: nil
      )
    end

    context 'when there are waiting team invitations for researcher' do
      let!(:team_invitation1) { create(:team_invitation, user: new_team_admin) }
      let!(:team_invitation2) { create(:team_invitation, user: new_team_admin) }
      let!(:accepted_team_invitation) { create(:team_invitation, :accepted, user: new_team_admin) }

      it 'not accepted yet invitations are removed' do
        expect { request }.to change(TeamInvitation, :count).by(-2)
        expect(team_invitation1).to be_removed
        expect(team_invitation2).to be_removed
        expect(accepted_team_invitation).to exist
      end
    end
  end

  context 'when params are valid, new team admin is team_admin' do
    let!(:new_team_admin) { create(:user, :confirmed, :team_admin) }
    let(:params) do
      {
        team: {
          name: 'Best Team',
          user_id: new_team_admin.id
        }
      }
    end
    let(:new_team) { Team.order(:created_at).last }

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new team with proper name, sets team admin as team\'s admin' do
      expect { request }.to change(Team, :count).by(1)

      expect(new_team).to have_attributes(
        name: 'Best Team',
        team_admin_id: new_team_admin.id
      )
      expect(new_team_admin.reload).to have_attributes(
        roles: ['team_admin'],
        team_id: nil
      )
    end
  end

  context 'when params are invalid' do
    context 'when team params are missing' do
      let(:params) { { team: {} } }

      it 'does not create new team, returns :bad_request status' do
        expect { request }.not_to change(Team, :count)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when name is missing' do
      let(:params) { { team: { name: '' } } }

      it 'does not create new team, returns :unprocessable_entity status' do
        expect { request }.not_to change(Team, :count)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user_id is missing' do
      let(:params) { { team: { name: 'Team A', user_id: 'non-existing' } } }

      it 'does not create a new team, returns :not_found status' do
        expect { request }.not_to change(Team, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let(:params) { {} }

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end
end
