# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/teams/:team_id/remove_researcher', type: :request do
  let(:request) { delete v1_team_remove_researcher_path(team_id: team.id), params: params, headers: headers }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:headers) { user.create_new_auth_token }
  let!(:team) { create :team }

  context 'when params are valid' do
    let(:params) do
      {
        user_id: team_user.id
      }
    end

    shared_examples 'permitted user' do
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

    shared_examples 'non-permitted user' do
      let(:team_user) { create(:user, :confirmed, :researcher, team_id: team.id) }

      it 'returns :forbidden status' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      describe '#permitted user' do
        let(:user) { users[role] }

        it_behaves_like 'permitted user'
      end
    end

    %w[researcher participant e_intervention_admin organization_admin health_system_admin health_clinic_admin third_party].each do |role|
      describe '#non-permitted user' do
        let(:user) { create(:user, :confirmed, roles: [role]) }

        it_behaves_like 'non-permitted user'
      end
    end

    context 'when user is team admin' do
      context 'when team admin wants to remove researcher of his team' do
        let(:user) { team.team_admin }

        it_behaves_like 'permitted user'
      end

      context 'when team admin wants to remove researcher of other team' do
        let(:other_team) { create(:team) }
        let(:user) { other_team.team_admin }
        let(:team_user) { create(:user, :confirmed, :researcher, team_id: team.id) }

        it 'returns :not_found status' do
          request
          expect(response).to have_http_status(:not_found)
        end
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
