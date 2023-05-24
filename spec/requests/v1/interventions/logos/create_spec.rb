# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:interventions_id/logo', type: :request do
  let(:current_user) { create(:user, :confirmed, :admin) }
  let(:other_user) { create(:user, :confirmed, :participant) }
  let(:other_user2) { create(:user, :confirmed, :third_party) }
  let(:intervention) { create(:intervention, user: current_user) }
  let(:params) do
    {
      logo: {
        file: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
      }
    }
  end
  let(:intervention_id) { intervention.id }
  let(:published_intervention) do
    create(:intervention, user: current_user, status: :published,
                          logo: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true))
  end
  let(:published_intervention_id) { published_intervention.id }

  context 'when current_user is admin' do
    context 'when current_user adds a logo' do
      before do
        post v1_intervention_logo_path(intervention_id), params: params, headers: current_user.create_new_auth_token
      end

      it { expect(response).to have_http_status(:created) }

      it 'JSON response contains proper attributes' do
        logo_url = polymorphic_url(intervention.reload.logo).sub('http://www.example.com/', '')
        expect(json_response['data']['attributes']).to include(
          'logo_url' => include(logo_url)
        )
      end
    end
  end

  context 'when current_user is participant' do
    context 'when current_user try to add a logo' do
      before do
        post v1_intervention_logo_path(intervention_id), params: params, headers: other_user.create_new_auth_token
      end

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

    before do
      post v1_intervention_logo_path(intervention_id), params: params, headers: current_user.create_new_auth_token
    end

    it {
      expect(response).to have_http_status(:forbidden)
    }
  end
end
