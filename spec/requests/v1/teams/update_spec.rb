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

      context 'when team admin has changed' do
        let!(:team_admin) { create(:user, :team_admin, team_id: team.id) }
        let(:researcher) { create(:user, :researcher) }
        let(:params) do
          {
            team: {
              user_id: researcher.id
            }
          }
        end

        it 'sets researcher as new team_admin and sets team_admin as researcher' do
          expect { request }.to change { researcher.reload.roles }.from(['researcher']).to(['team_admin']).and \
            change(researcher, :team_id).from(nil).to(team.id).and \
              change { team_admin.reload.roles }.from(['team_admin']).to(['researcher']).and \
                avoid_changing { team_admin.team_id }
        end
      end

      context 'name param is not present' do
        let(:params) { { team: { name: '' } } }

        it 'does not update team' do
          expect_any_instance_of(Team).not_to receive(:update!)
          request
        end
      end

      context 'when name didn\'t change' do
        let(:params) { { team: { name: team.name } } }

        it 'does not update team' do
          expect_any_instance_of(Team).not_to receive(:update!)
          request
        end
      end

      context 'user_id param is not present' do
        let(:params) { { team: { user_id: '' } } }

        it 'does not update team' do
          expect_any_instance_of(User).not_to receive(:update!)
          request
        end
      end

      context 'when team admin didn\'t change' do
        let!(:team_admin) { create(:user, :team_admin, team_id: team.id) }
        let(:params) { { team: { user_id: team_admin.id } } }

        it 'does not update team' do
          expect_any_instance_of(User).not_to receive(:update!)
          request
        end
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
