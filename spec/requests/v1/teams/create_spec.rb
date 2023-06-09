# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/teams', type: :request do
  let(:request) { post v1_teams_path, params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      team: {
        name: 'Best Team',
        user_id: new_team_admin.id
      }
    }
  end

  shared_examples 'new team created properly' do
    let(:new_team) { Team.order(:created_at).first }

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new team with proper name, sets user as team admin' do
      expect { request }.to change(Team, :count).by(1)
      expect(new_team).to have_attributes(
        name: 'Best Team',
        team_admin_id: new_team_admin.id
      )
      expect(new_team_admin.reload).to have_attributes(
        roles: %w[researcher team_admin],
        team_id: nil
      )
    end
  end

  shared_examples 'new team is forbidden to create' do
    let(:params) { {} }

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end

  context 'when params are valid, new team admin is researcher' do
    let(:new_team_admin) { create(:user, :confirmed, :researcher) }

    it_behaves_like 'new team created properly'

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

    it_behaves_like 'new team created properly'
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

  %w[researcher participant e_intervention_admin organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context 'when user is not super admin' do
      let(:user) { create(:user, :confirmed, roles: [role]) }

      it_behaves_like 'new team is forbidden to create'
    end
  end

  context 'when user is team admin' do
    let!(:team) { create(:team) }
    let(:user) { team.team_admin }

    it_behaves_like 'new team is forbidden to create'
  end
end
