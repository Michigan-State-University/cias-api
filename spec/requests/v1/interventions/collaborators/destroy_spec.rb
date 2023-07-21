# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/collaborators/:id', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_collaborators, user: user) }
  let(:collaborator) { intervention.collaborators.first }
  let(:current_user) { user }

  let(:request) { delete v1_intervention_collaborator_path(intervention_id: intervention.id, id: collaborator.id), headers: current_user.create_new_auth_token }

  before { request }

  context 'when the user is an owner' do
    it 'return correct status' do
      expect(response).to have_http_status(:no_content)
    end

    it 'intervention shouldn\'t have any collaborators' do
      expect(intervention.reload.collaborators.count).to be 0
    end
  end

  context 'when user without access' do
    let(:current_user) { create(:user, :participant, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when other researcher wants to do that' do
    let(:current_user) { create(:user, :researcher, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
