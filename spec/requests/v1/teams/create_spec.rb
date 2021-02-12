# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/teams', type: :request do
  let(:request) { post v1_teams_path, params: params, headers: headers }
  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:params) do
      {
        team: {
          name: 'Best Team',
          user_id: researcher.id
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new team with proper name, sets researcher as team admin' do
      expect { request }.to change(Team, :count).by(1)

      expect(Team.last).to have_attributes(
        name: 'Best Team'
      )
      expect(researcher.reload).to have_attributes(
        team_id: json_response.dig('data', 'id'),
        roles: ['team_admin']
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
        expect(response).to have_http_status(:unprocessable_entity)
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
