# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:interventions_id/logo', type: :request do
  let(:current_user) { create(:user, :confirmed, :admin) }
  let(:other_user) { create(:user, :confirmed, :participant) }
  let(:intervention) do
    create(:intervention, user: current_user, logo: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true))
  end
  let(:intervention_id) { intervention.id }
  let(:published_intervention) do
    create(:intervention, user: current_user, status: :published,
                          logo: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true))
  end
  let(:published_intervention_id) { published_intervention.id }

  context 'when current_user is admin' do
    before { delete v1_intervention_logo_path(intervention_id), headers: current_user.create_new_auth_token }

    context 'wden current_user deletes a logo' do
      it { expect(response).to have_http_status(:no_content) }

      it 'removes attached logo' do
        expect(intervention.reload.logo.attachment).to be_nil
      end
    end
  end

  context 'when other_user updates logo' do
    before { delete v1_intervention_logo_path(intervention_id), headers: other_user.create_new_auth_token }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context 'when intervention is published' do
    before { delete v1_intervention_logo_path(published_intervention_id), headers: current_user.create_new_auth_token }

    it { expect(response).to have_http_status(:method_not_allowed) }
  end

  context 'when collaborator has edit access' do
    let(:intervention) { create(:intervention, :with_collaborators) }
    let(:current_user) { intervention.collaborators.first.user }

    before do
      intervention.update(current_editor: current_user)
      delete v1_intervention_logo_path(intervention_id), headers: current_user.create_new_auth_token
    end

    it {
      expect(response).to have_http_status(:no_content)
    }

    context 'when current editor is empty' do
      before do
        intervention.update(current_editor: nil)

        delete v1_intervention_logo_path(intervention.id), headers: current_user.create_new_auth_token
      end

      it {
        expect(response).to have_http_status(:forbidden)
      }
    end
  end
end
