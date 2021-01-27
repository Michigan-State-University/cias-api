# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/teams', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when there are teams' do
    let!(:team_1) { create(:team) }
    let!(:team_2) { create(:team) }

    before do
      get v1_teams_path, headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns list of teams' do
      expect(json_response['data']).to include(
        'id' => team_1.id.to_s,
        'type' => 'team',
        'attributes' => include('name' => team_1.name)
      ).and include(
        'id' => team_2.id.to_s,
        'type' => 'team',
        'attributes' => include('name' => team_2.name)
      )
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
