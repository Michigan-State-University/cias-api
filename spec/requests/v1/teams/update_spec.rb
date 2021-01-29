# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/teams/:id', type: :request do
  let(:request) { patch v1_team_path(team.id), params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:team) { create :team }
  let(:params) do
    {
      team: {
        name: 'Best Team'
      }
    }
  end

  context 'when params' do
    context 'valid' do
      it 'returns :ok status' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'updates team attributes' do
        expect { request }.to change { team.reload.name }.from(team.name).to('Best Team').and \
          avoid_changing { Team.count }
      end
    end

    context 'invalid' do
      context 'params' do
        let(:params) { { team: {} } }

        it 'returns :bad_request status' do
          request
          expect(response).to have_http_status(:bad_request)
        end

        it 'does not update team attributes' do
          expect { request }.not_to change(team, :name)
        end
      end
    end
  end
end
