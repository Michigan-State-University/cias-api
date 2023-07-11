# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/permission', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_collaborators, user: user) }
  let(:collaborator) { intervention.collaborators.first }
  let(:current_user) { collaborator.user }

  let(:request) do
    get v1_intervention_permission_path(intervention_id: intervention.id), headers: current_user.create_new_auth_token
  end

  before { request }

  context 'for collaborator' do
    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'update collaborator access' do
      expect(json_response['data']['attributes'].keys).to match_array(%w[id view edit data_access])
    end
  end

  context 'no collaborator' do
    let(:current_user) { user }

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
