# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:id/user_data', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:other_researcher) { create(:user, :confirmed, :researcher) }

  let(:user) { admin }
  let(:owner) { admin }
  let(:status) { :closed }
  let(:sensitive_data_state) { 'collected' }

  let(:intervention) { create(:intervention, :with_csv_file, status: status, user: owner, sensitive_data_state: sensitive_data_state) }
  let!(:user_intervention) { create(:user_intervention, intervention: intervention) }
  let(:params) { { delay: 5 } }

  let(:request) do
    delete user_data_v1_intervention_path(id: intervention.id), params: params, headers: user.create_new_auth_token
  end

  shared_examples 'can clear user data' do
    it 'returns the status no_content' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'response has expected information' do
      request
      expect(json_response['data']['attributes']['clear_sensitive_data_scheduled_at'].present?).to be true
    end

    it 'sets the "sensitive_data_state" flag to "prepared_to_remove"' do
      request
      expect(intervention.reload.sensitive_data_marked_to_remove?).to be(true)
    end

    it 'does enqueued job' do
      request
      expect(DataClearJobs::ClearUserData).to have_been_enqueued.with(intervention.id)
    end
  end

  shared_examples 'cannot clear user data' do
    it 'returns the status forbidden' do
      request
      expect(response).to have_http_status(:forbidden)
    end

    it 'leaves the cleared flag unchanged' do
      expect { request }.not_to change { intervention.reload.sensitive_data_state }
    end

    it 'does not enqueued job' do
      request
      expect(DataClearJobs::ClearUserData).not_to have_been_enqueued.with(intervention.id)
    end
  end

  shared_examples 'cannot access user data' do
    it 'returns the status forbidden' do
      request
      expect(response).to have_http_status(:not_found)
    end

    it 'leaves the cleared flag unchanged' do
      expect { request }.not_to change { intervention.reload.sensitive_data_state }
    end
  end

  context 'when all conditions are valid' do
    let(:intervention) { create(:intervention, :with_pdf_report, status: :closed, user: owner) }

    it 'does not delete reports' do
      expect { request }.not_to change { intervention.reload.reports.count }
    end
  end

  %i[closed archived].each do |status|
    context "when intervention is #{status}" do
      let!(:status) { status }

      it_behaves_like 'can clear user data'
    end
  end

  %i[draft published].each do |status|
    context "when intervention is #{status}" do
      let!(:status) { status }

      it_behaves_like 'cannot clear user data'
    end
  end

  context 'when the intervention was already cleared' do
    let!(:sensitive_data_state) { 'removed' }

    it_behaves_like 'cannot clear user data'
  end

  context 'when researcher tries to clear data in their own intervention' do
    let!(:user) { researcher }
    let!(:owner) { researcher }

    it_behaves_like 'can clear user data'
  end

  context 'when researcher tries to clear data in other researcher\'s intervention' do
    let!(:user) { researcher }
    let!(:owner) { other_researcher }

    it_behaves_like 'cannot access user data'
  end

  context 'when admin tries to clear data not in their intervention' do
    let!(:user) { admin }
    let!(:owner) { other_researcher }

    it_behaves_like 'cannot clear user data'
  end

  context 'when the intervention is collaborative' do
    let!(:intervention) do
      create(:intervention, :with_csv_file,
             collaborators: [
               create(:collaborator, user: other_researcher, edit: true, view: true, data_access: true),
               create(:collaborator, user: admin, edit: true, view: true, data_access: true)
             ],
             status: :closed, user: researcher, current_editor: editor)
    end

    context 'when the owner is the current editor' do
      let!(:user) { researcher }
      let!(:editor) { researcher }

      it_behaves_like 'can clear user data'
    end

    context 'when the owner is not the current editor' do
      let!(:user) { researcher }
      let!(:editor) { other_researcher }

      it_behaves_like 'cannot clear user data'
    end

    context 'when admin is the current editor but not an owner' do
      let!(:user) { admin }
      let!(:editor) { admin }

      it_behaves_like 'cannot clear user data'
    end
  end
end
