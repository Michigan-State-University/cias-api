# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/csv_attachment', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, :with_collaborators, user: researcher, reports: reports) }
  let(:reports) { [FactoryHelpers.upload_file('spec/factories/csv/test_empty.csv', 'text/csv', true)] }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_fetch_protected_csv_path(intervention.id), headers: headers }
  let(:intervention_owner) { admin }
  let(:user) { researcher }
  let(:action_path) { ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(intervention.newest_report, only_path: true) }

  context 'when owner of the intervention wants to fetch the intervention csv' do
    before { request }

    it 'returns OK' do
      expect(response).to have_http_status(:found)
    end

    it 'redirect to correct resource' do
      expect(response).to redirect_to(action_path)
    end
  end

  context 'collaborator without access data' do
    let(:user) { intervention.collaborators.first.user }

    before { request }

    it 'returns forbidden' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'collaborator with access' do
    let(:user) { intervention.collaborators.first.user }

    before do
      intervention.collaborators.first.update!(data_access: true)
    end

    it 'returns OK' do
      request
      expect(response).to have_http_status(:found)
    end

    context 'when collaborator is also an admin' do
      let(:user) { create(:user, :admin, :confirmed) }

      before do
        Collaborator.create!(intervention: intervention, user: user, data_access: true)
        request
      end

      it 'returns OK' do
        expect(response).to have_http_status(:found)
      end
    end
  end
end
