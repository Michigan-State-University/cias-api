# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH  /v1/interventions/:interventions_id/logo', type: :request do
  let(:current_user) { create(:user, :confirmed, :admin) }
  let(:other_user) { create(:user, :confirmed, :participant) }
  let(:other_user2) { create(:user, :confirmed, :third_party) }
  let(:intervention) { create(:intervention_with_logo, user: current_user) }
  let(:params) do
    {
      logo: {
        image_alt: 'New logo'
      }
    }
  end
  let(:intervention_id) { intervention.id }
  let(:published_intervention) { create(:intervention_with_logo, user: current_user, status: :published) }
  let(:published_intervention_id) { published_intervention.id }

  let(:request) { patch v1_intervention_logo_path(intervention_id), params: params, headers: current_user.create_new_auth_token }

  context 'when current_user is admin' do
    context 'when current_user adds a description' do
      before { request }

      it 'JSON response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'image_alt' => 'New logo'
        )
      end
    end
  end

  context 'when current_user is participant' do
    context 'when current_user try to add a logo' do
      before { post v1_intervention_logo_path(intervention_id), params: params, headers: other_user.create_new_auth_token }

      it { expect(response).to have_http_status(:forbidden) }
    end
  end

  context 'when current_user is third_party' do
    context 'when current_user try to add a logo' do
      before { post v1_intervention_logo_path(intervention_id), params: params, headers: other_user2.create_new_auth_token }

      it { expect(response).to have_http_status(:forbidden) }
    end
  end

  context 'when intervention is published' do
    before { delete v1_intervention_logo_path(published_intervention_id), headers: current_user.create_new_auth_token }

    it { expect(response).to have_http_status(:method_not_allowed) }
  end

  context 'when current user is collaborator' do
    let(:intervention) { create(:intervention) }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: false) }
    let(:current_user) { collaborator.user }

    before { request }

    it {
      expect(response).to have_http_status(:forbidden)
    }
  end

  context 'when collaborator has edit access' do
    let(:intervention) { create(:intervention, :with_collaborators) }
    let(:current_user) { intervention.collaborators.first.user }

    before do
      intervention.update(current_editor: current_user)
    end

    it {
      request
      expect(response).to have_http_status(:ok)
    }

    context 'when current editor is empty' do
      before do
        intervention.update(current_editor: nil)
        request
      end

      it {
        expect(response).to have_http_status(:forbidden)
      }
    end
  end
end
