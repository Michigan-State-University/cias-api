# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/teams/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:team_1) { create(:team) }

  context 'when there is a team with given id' do
    before do
      get v1_team_path(id: team_1.id), headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns list of teams' do
      expect(json_response['data']).to include(
        'id' => team_1.id.to_s,
        'type' => 'team',
        'attributes' => include('name' => team_1.name)
      )
    end
  end

  context 'when there is no team with given id' do
    before do
      get v1_team_path(id: 'non-existing-id'), headers: headers
    end

    it 'has correct http code :not_found' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
