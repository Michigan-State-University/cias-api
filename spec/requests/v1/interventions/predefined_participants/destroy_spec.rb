# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/predefined_participants/:id', type: :request do
  let(:request) do
    delete v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user.id), headers: current_user.create_new_auth_token
  end
  let!(:intervention) { create(:intervention, :with_predefined_participants, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let!(:user) { intervention.predefined_users.first }

  it 'return correct status' do
    request
    expect(response).to have_http_status(:no_content)
  end

  it 'does not delete the user' do
    expect { request }.not_to change(User, :count)
  end

  it_behaves_like 'users without access'

  context 'researcher deactivates the account' do
    it 'activates the user' do
      expect { request }.to change { user.reload.active }.to(false)
    end
  end

  context 'when intervention has collaborators' do
    let!(:intervention) { create(:intervention, :with_predefined_participants, :with_collaborators, user: researcher) }

    it 'no editing mode' do
      request
      expect(response).to have_http_status(:forbidden)
    end

    context 'current editor' do
      let(:current_user) { intervention.collaborators.first.user }

      before do
        intervention.update(current_editor: current_user)
      end

      it 'current editor has access to the action' do
        request
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
