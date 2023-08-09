# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:id/user_data', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:other_researcher) { create(:user, :confirmed, :researcher) }

  let(:user) { admin }
  let(:owner) { admin }
  let(:status) { :closed }
  let(:reports_deleted) { false }

  let(:intervention) { create(:intervention, :with_pdf_report, status: status, user: owner, reports_deleted: reports_deleted) }

  let(:request) do
    delete user_reports_v1_intervention_path(id: intervention.id), headers: user.create_new_auth_token
  end

  shared_examples 'can clear user reports' do
    it 'returns the status no_content' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'sets the "reports_deleted" flag to true' do
      request
      expect(intervention.reload.reports_deleted?).to eq(true)
    end

    it 'removes all the generated reports' do
      request
      expect(intervention.reload.reports).to be_empty
    end

    it 'removes attachments' do
      expect { request }.to change { ActiveStorage::Attachment.count }.by_at_most(-1)
    end
  end

  shared_examples 'cannot clear user reports' do
    it 'returns the status forbidden' do
      request
      expect(response).to have_http_status(:forbidden)
    end

    it 'leaves the reports_deleted flag unchanged' do
      expect { request }.not_to change { intervention.reload.reports_deleted? }
    end

    it 'does not remove any generated reports' do
      expect { request }.not_to change { intervention.reload.reports.count }
    end

    it 'does not delete any attachments' do
      expect { request }.not_to change { ActiveStorage::Attachment.count }
    end
  end

  shared_examples 'cannot access user reports' do
    it 'returns the status forbidden' do
      request
      expect(response).to have_http_status(:not_found)
    end

    it 'leaves the reports_deleted flag unchanged' do
      expect { request }.not_to change { intervention.reload.reports_deleted? }
    end

    it 'does not remove any generated reports' do
      expect { request }.not_to change { intervention.reload.reports.count }
    end

    it 'does not delete any attachments' do
      expect { request }.not_to change { ActiveStorage::Attachment.count }
    end
  end

  context 'when all conditions are valid' do
    let(:intervention) { create(:intervention, :with_csv_file, status: :closed, user: owner) }
    let!(:user_intervention) { create(:user_intervention, intervention: intervention) }

    it 'doesnt clear any user sessions for the intervention' do
      expect { request }.not_to change { intervention.reload.user_interventions.count }
    end

    it 'does not delete generated csv files' do
      expect { request }.not_to change { intervention.reload.files.count }
    end
  end

  %i[closed archived].each do |status|
    context "when intervention is #{status}" do
      let!(:status) { status }

      it_behaves_like 'can clear user reports'
    end
  end

  %i[draft published].each do |status|
    context "when intervention is #{status}" do
      let!(:status) { status }

      it_behaves_like 'cannot clear user reports'
    end
  end

  context 'when the intervention was already cleared' do
    let!(:reports_deleted) { true }

    it_behaves_like 'cannot clear user reports'
  end

  context 'when researcher tries to clear data in their own intervention' do
    let!(:user) { researcher }
    let!(:owner) { researcher }

    it_behaves_like 'can clear user reports'
  end

  context 'when researcher tries to clear data in other researcher\'s intervention' do
    let!(:user) { researcher }
    let!(:owner) { other_researcher }

    it_behaves_like 'cannot access user reports'
  end

  context 'when admin tries to clear data not in their intervention' do
    let!(:user) { admin }
    let!(:owner) { other_researcher }

    it_behaves_like 'cannot clear user reports'
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

      it_behaves_like 'can clear user reports'
    end

    context 'when the owner is not the current editor' do
      let!(:user) { researcher }
      let!(:editor) { other_researcher }

      it_behaves_like 'cannot clear user reports'
    end

    context 'when admin is the current editor but not an owner' do
      let!(:user) { admin }
      let!(:editor) { admin }

      it_behaves_like 'cannot clear user reports'
    end
  end
end
