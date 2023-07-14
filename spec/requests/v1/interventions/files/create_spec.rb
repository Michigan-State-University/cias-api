# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/files', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:flexible_order_intervention, user: user) }
  let(:sample_file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }
  let(:params) do
    {
      intervention: {
        files: [sample_file]
      }
    }
  end

  let(:request) { post v1_intervention_files_path(intervention.id), params: params, headers: headers }

  shared_examples 'permitted user' do
    before { request }

    context 'is success' do
      it { expect(response).to have_http_status(:created) }

      it 'return correct data' do
        file_url = polymorphic_url(intervention.reload.files.first).sub('http://www.example.com/', '')
        expect(json_response['data']['attributes']['files'].first).to include(
          'id' => intervention.reload.files.first.id,
          'name' => include('test_image_1.jpg'),
          'url' => include(file_url)
        )
      end
    end

    context 'when intervention cannot have files' do
      let(:intervention) { create(:intervention, user: user) }

      it { expect(response).to have_http_status(:method_not_allowed) }
    end
  end

  shared_examples 'unpermitted user' do
    before { request }

    it 'returns proper error message' do
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end

  %i[team_admin researcher admin e_intervention_admin].each do |role|
    context "user is #{role}" do
      let(:user) { create(:user, :confirmed, role) }
      let(:headers) { user.create_new_auth_token }

      it_behaves_like 'permitted user'
    end
  end

  %i[health_system_admin organization_admin participant guest health_clinic_admin].each do |role|
    context "user is #{role}" do
      let(:user) { create(:user, :confirmed, role) }
      let(:headers) { user.create_new_auth_token }

      it_behaves_like 'unpermitted user'
    end
  end

  context 'when current user is collaborator' do
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: false) }
    let(:headers) { collaborator.user.create_new_auth_token }

    before { request }

    it {
      expect(response).to have_http_status(:forbidden)
    }

    context 'when has edit access' do
      let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: true) }

      it { expect(response).to have_http_status(:created) }
    end
  end

  context 'file is too big' do
    let(:user) { create(:user, :confirmed, :admin) }
    let(:headers) { user.create_new_auth_token }
    let(:intervention) { create(:flexible_order_intervention, user: user) }
    let(:sample_file) do
      FactoryHelpers.upload_file('spec/factories/text/big_file.txt', 'text/plain', false)
    end

    it 'returns correct HTTP status code (Payload Too Large)' do
      request
      expect(response).to have_http_status(:payload_too_large)
    end
  end
end
