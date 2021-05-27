# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/teams', type: :request do
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

  context 'when there are teams' do
    let!(:team1) { create(:team) }
    let!(:team_1_researcher) { create(:user, :researcher) }
    let!(:team2) { create(:team) }
    let!(:team_2_researcher) { create(:user, :researcher) }
    let(:team_1_admin) { team1.team_admin }
    let(:team_2_admin) { team2.team_admin }

    before do
      team1.users << team_1_researcher
      team2.users << team_2_researcher
      get v1_teams_path, headers: headers
    end

    shared_examples 'permitted user' do
      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns list of teams with team admins details' do
        expect(json_response['data']).to include(
          'id' => team1.id.to_s,
          'type' => 'team',
          'attributes' => include('name' => team1.name, 'team_admin_id' => team_1_admin.id),
          'relationships' => {
            'team_admin' => {
              'data' => include('id' => team_1_admin.id, 'type' => 'team_admin')
            }
          }
        ).and include(
          'id' => team2.id.to_s,
          'type' => 'team',
          'attributes' => include('name' => team2.name, 'team_admin_id' => team_2_admin.id),
          'relationships' => {
            'team_admin' => {
              'data' => include('id' => team_2_admin.id, 'type' => 'team_admin')
            }
          }
        )

        expect(json_response['included']).to include(
          'id' => team_2_admin.id,
          'type' => 'user',
          'attributes' => include(
            'email' => team_2_admin.email,
            'full_name' => team_2_admin.full_name,
            'roles' => ['team_admin'],
            'team_id' => nil,
            'admins_team_ids' => [team2.id]
          )
        ).and include(
          'id' => team_1_admin.id,
          'type' => 'user',
          'attributes' => include(
            'email' => team_1_admin.email,
            'full_name' => team_1_admin.full_name,
            'roles' => ['team_admin'],
            'team_id' => nil,
            'admins_team_ids' => [team1.id]
          )
        )

        expect(json_response['meta']).to include(
          'teams_size' => 2
        )
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'when there are no teams' do
    before do
      get v1_teams_path, headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'success to Hash' do
      expect(json_response['data']).to be_empty
    end
  end
end
