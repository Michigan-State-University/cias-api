# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/teams/:id/add_team_admin', type: :request do
  let(:request) do
    post add_team_admin_v1_team_path(team.id), params: params, headers: headers
  end
  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:team) { create(:team, :with_team_admin) }

  context 'when params are valid' do
    let(:params) do
      {
        user_id: researcher.id
      }
    end
    let!(:team_admin) { team.team_admin }

    it 'returns :ok status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'sets researcher as new team_admin and sets team_admin as team member' do
      expect { request }.to change { researcher.reload.roles }.from(['researcher']).to(['team_admin']).and \
        change(researcher, :team_id).from(nil).to(team.id).and \
          change { team_admin.reload.roles }.from(['team_admin']).to(['researcher']).and \
            avoid_changing { team_admin.team_id }
    end
  end

  context 'when params are invalid' do
    context 'when team id is incorrect' do
      let(:team) { double(id: 'invalid') }
      let(:params) { { user_id: researcher.id } }

      it 'returns :not_found' do
        expect { request }.not_to change(researcher, :roles)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user_id is missing' do
      let(:params) { { user_id: '' } }

      it 'returns :bad_request status' do
        request
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when user_id is not researcher' do
      let(:participant) { create(:user, :participant) }
      let(:params) { { user_id: participant.id } }

      it 'returns :not_found status' do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let(:params) { { user_id: researcher.id } }

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end
end
