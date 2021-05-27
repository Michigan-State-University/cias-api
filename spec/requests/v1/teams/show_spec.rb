# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/teams/:id', type: :request do
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
  let!(:team1) { create(:team) }

  context 'when there is a team with given id' do
    before do
      get v1_team_path(id: team1.id), headers: headers
    end

    shared_examples 'permitted user' do
      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns list of teams' do
        expect(json_response['data']).to include(
          'id' => team1.id.to_s,
          'type' => 'team',
          'attributes' => include('name' => team1.name)
        )
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'when there is no team with given id' do
    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }
      before do
        get v1_team_path(id: 'non-existing-id'), headers: headers
      end

      it 'has correct http code :not_found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
