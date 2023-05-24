# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/collaborators/:id', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_collaborators, user: user) }
  let(:collaborator) { intervention.collaborators.first }
  let(:current_user) { user }
  let(:params) do
    {
      collaborator: {
        view: true,
        edit: true,
        data_access: true
      }
    }
  end

  let(:request) do
    patch v1_intervention_collaborator_path(intervention_id: intervention.id, id: collaborator.id), params: params, headers: current_user.create_new_auth_token
  end

  before { request }

  context 'when the user is an owner' do
    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'update collaborator access' do
      expect(collaborator.reload.attributes.deep_transform_keys(&:to_sym)).to include({ view: true, edit: true, data_access: true })
    end
  end

  context 'when collaborator wants to add another collaborator' do
    let(:intervention) { create(:intervention, :with_collaborators, user: user) }
    let(:current_user) { intervention.collaborators.first.user }

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when user without access' do
    let(:current_user) { create(:user, :participant, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end
  end
end
