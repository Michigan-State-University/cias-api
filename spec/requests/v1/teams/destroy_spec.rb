# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/teams/:id', type: :request do
  let(:request) { delete v1_team_path(team_id), headers: headers }
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
  let(:team_id) { team.id }

  context 'when team with given id exists' do
    shared_examples 'permitted user' do
      it 'returns :no_content status' do
        request
        expect(response).to have_http_status(:no_content)
      end

      it 'destroys a team' do
        expect { request }.to change(Team, :count).by(-1)
      end

      context 'with team admin, with only one team' do
        let!(:team_admin) { team.team_admin }

        it 'changes team admin role to researcher after removing team' do
          expect { request }.to change { team_admin.reload.roles }.from(%w[researcher team_admin]).to(['researcher'])
        end
      end

      context 'with team admin, with other teams' do
        let!(:team_admin) { team.team_admin }
        let!(:other_team) { create(:team, team_admin: team_admin) }

        it 'does not change team admin role' do
          expect { request }.to avoid_changing { team_admin.reload.roles }
        end
      end
    end

    shared_examples 'non-permitted user' do
      it 'returns :forbidden status' do
        request
        expect(response).to have_http_status(:forbidden)
      end

      it 'not destroys a team' do
        expect { request }.not_to change(Team, :count)
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
      context 'wants to delete his team' do
        let(:user) { team.team_admin }

        it_behaves_like 'non-permitted user'
      end

      context 'wants to delete other team' do
        let!(:other_team) { create :team }
        let(:user) { other_team.team_admin }

        it_behaves_like 'non-permitted user'
      end
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
