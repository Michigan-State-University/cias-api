# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/files/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:flexible_order_intervention_with_file, user: user) }
  let(:file_id) { intervention.files.first.id }

  let(:request) { delete v1_intervention_file_path(intervention.id, file_id), headers: headers }

  shared_examples 'permitted user' do
    before { request }

    context 'is success' do
      it { expect(response).to have_http_status(:ok) }

      it 'return correct data' do
        expect(json_response['data']['attributes']['files']).to be_nil
      end
    end

    context 'wrong id' do
      let(:file_id) { 'wrong_id' }

      it { expect(response).to have_http_status(:not_found) }

      it 'response have correct message' do
        expect(json_response['message']).to include("Couldn't find ActiveStorage::Attachment with 'id'=#{file_id}")
      end
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

    it_behaves_like 'unpermitted user'

    context 'when has edit access' do
      let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: true) }

      it_behaves_like 'permitted user'
    end
  end
end
