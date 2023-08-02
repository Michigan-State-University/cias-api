# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE v1/sessions/:session_id/report_templates/:id/remove_cover_letter_custom_logo', type: :request do
  let!(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }

  let(:request) do
    delete v1_session_report_template_remove_cover_letter_custom_logo_path(
             session_id: session.id, report_template_id: report_template.id
           ), headers: headers
  end

  let!(:report_template) { create(:report_template, :with_logo, :with_custom_cover_letter_logo, session: session) }

  shared_examples 'can delete the custom cover page logo' do
    it 'returns the response code for no content' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'removes the attachment' do
      expect { request }.to change(ActiveStorage::Attachment, :count).by(-1)
    end
  end

  shared_examples 'cannot delete the custom cover page logo' do
    it 'rejects the request' do
      request
      expect(response).to have_http_status(:forbidden)
    end

    it 'does not delete any attachments' do
      expect { request }.not_to change(ActiveStorage::Attachment, :count)
    end
  end

  context 'when deleting the custom cover letter logo' do
    let!(:user) { create(:user, :confirmed, :admin) }

    it_behaves_like 'can delete the custom cover page logo'
  end

  context 'when a user that\'s not the owner tries to delete the custom cover letter logo' do
    let!(:user) { create(:user, :participant, :confirmed) }

    it_behaves_like 'cannot delete the custom cover page logo'
  end

  context 'when the report is for a collaborative session' do
    let(:user) { create(:user, :researcher, :confirmed) }

    context 'when the user is the current editor' do
      let!(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: user) }

      it_behaves_like 'can delete the custom cover page logo'
    end

    context 'when the user is not the current editor' do
      let(:other_user) { create(:user, :researcher, :confirmed) }
      let!(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: other_user) }

      it_behaves_like 'cannot delete the custom cover page logo'
    end
  end
end
