# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/predefined_participants/:id', type: :request do
  let(:request) do
    patch v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user.id),
          params: params, headers: current_user.create_new_auth_token
  end
  let!(:intervention) { create(:intervention, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let(:user) { create(:user, :predefined_participant, :with_phone) }
  let(:params) do
    {
      predefined_user: {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name
      }
    }
  end

  before do
    PredefinedUserParameter.create(user: user, intervention: intervention)
  end

  it 'return correct status' do
    request
    expect(response).to have_http_status(:ok)
  end

  it 'return correct body' do
    request
    expect(json_response['data']['attributes'].keys).to match_array(%w[full_name first_name last_name phone slug health_clinic_id auto_invitation
                                                                       invitation_sent_at])
  end

  it_behaves_like 'users without access'

  context 'researcher activates the account' do
    let(:user) { create(:user, :predefined_participant, active: false) }
    let(:params) do
      {
        predefined_user: {
          active: true
        }
      }
    end

    it 'activates the user' do
      expect { request }.to change { user.reload.active }.to(true)
    end
  end

  context 'when intervention has collaborators' do
    let!(:intervention) { create(:intervention, :with_collaborators, user: researcher) }

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
        expect(response).to have_http_status(:ok)
      end
    end
  end
end