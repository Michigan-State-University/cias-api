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
  let(:params) { {} }

  context 'when there are teams' do
    let!(:team1) { create(:team, name: 'Super team') }
    let!(:team_1_researcher) { create(:user, :researcher) }
    let!(:team2) { create(:team, name: 'Other') }
    let!(:team_2_researcher) { create(:user, :researcher) }
    let(:team_1_admin) { team1.team_admin }
    let(:team_2_admin) { team2.team_admin }

    before do
      team1.users << team_1_researcher
      team2.users << team_2_researcher
      get v1_teams_path, headers: headers, params: params
    end

    shared_examples 'permitted user' do
      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      context 'without params' do
        it 'returns list of teams' do
          expect(json_response['data']).to include(
            {
              'id' => team1.id.to_s,
              'type' => 'team',
              'attributes' => include('name' => team1.name, 'team_admin_id' => team_1_admin.id),
              'relationships' => {
                'team_admin' => {
                  # if this stops working and for some reason returns team_admin then change it back to team_admin
                  'data' => include('id' => team_1_admin.id, 'type' => 'user')
                }
              }
            }
          ).and include(
            {
              'id' => team2.id.to_s,
              'type' => 'team',
              'attributes' => include('name' => team2.name, 'team_admin_id' => team_2_admin.id),
              'relationships' => {
                'team_admin' => {
                  'data' => include('id' => team_2_admin.id, 'type' => 'user') # ditto
                }
              }
            }
          )
        end

        it 'returns team admins details' do
          expect(json_response['included']).to include(
            'id' => team_2_admin.id,
            'type' => 'user',
            'attributes' => include(
              'email' => team_2_admin.email,
              'full_name' => team_2_admin.full_name,
              'roles' => %w[researcher team_admin],
              'team_id' => nil,
              'admins_team_ids' => [team2.id]
            )
          ).and include(
            'id' => team_1_admin.id,
            'type' => 'user',
            'attributes' => include(
              'email' => team_1_admin.email,
              'full_name' => team_1_admin.full_name,
              'roles' => %w[researcher team_admin],
              'team_id' => nil,
              'admins_team_ids' => [team1.id]
            )
          )
        end

        it 'returns proper size of collection' do
          expect(json_response['meta']).to include(
            'teams_size' => 2
          )
        end
      end

      context 'with params' do
        let(:params) { { name: 'Super' } }

        it 'returns correct team' do
          expect(json_response['data']).to include(
            'id' => team1.id.to_s,
            'type' => 'team',
            'attributes' => include(
              'name' => team1.name,
              'team_admin_id' => team_1_admin.id
            ),
            'relationships' => {
              'team_admin' => {
                'data' => include(
                  'id' => team_1_admin.id,
                  'type' => 'user'
                )
              }
            }
          )

          expect(json_response['meta']).to include(
            'teams_size' => 1
          )
        end
      end
    end

    shared_examples 'non-permitted user' do
      it 'returns :forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      context 'permitted user' do
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

    context 'when user is team admin with one team' do
      let(:user) { team_1_admin }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns list of teams' do
        expect(json_response['data'].size).to be 1
        expect(json_response['data']).to include(
          'id' => team1.id.to_s,
          'type' => 'team',
          'attributes' => include('name' => team1.name, 'team_admin_id' => team_1_admin.id),
          'relationships' => {
            'team_admin' => {
              'data' => include('id' => team_1_admin.id, 'type' => 'user')
            }
          }
        )
      end

      it 'returns team admins details' do
        expect(json_response['included']).to include(
          'id' => team_1_admin.id,
          'type' => 'user',
          'attributes' => include(
            'email' => team_1_admin.email,
            'full_name' => team_1_admin.full_name,
            'roles' => %w[researcher team_admin],
            'team_id' => nil,
            'admins_team_ids' => [team1.id]
          )
        )
      end

      it 'returns proper size of collection' do
        expect(json_response['meta']).to include(
          'teams_size' => 1
        )
      end
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
