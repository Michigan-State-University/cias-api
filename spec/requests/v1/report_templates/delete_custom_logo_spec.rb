# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE v1/sessions/:session_id/report_templates/:id/remove_cover_letter_custom_logo', type: :request do
  let!(:headers) { user.create_new_auth_token }
  let!(:session) { create(:session) }

  let(:request) do
    delete v1_session_report_template_remove_cover_letter_custom_logo_path(
      session_id: session.id, report_template_id: report_template.id
    ), headers: headers
  end

  let!(:report_template) { create(:report_template, :with_logo, :with_custom_cover_letter_logo, session: session) }

  context 'when deleting the custom cover letter logo' do
    let!(:user) { create(:user, :confirmed, :admin) }

    it 'removes the attachment' do
      expect { request }.to change(ActiveStorage::Attachment, :count).by(-1)
    end

    it 'returns the response code for no content' do
      request
      expect(response).to have_http_status(:no_content)
    end
  end

  context 'when a user that\'s not the owner' do
    let!(:user) { create(:user, :confirmed) }

    it 'rejects the request' do
      request
      expect(response).to have_http_status(:forbidden)
    end

    it 'does not delete any attachments' do
      expect { request }.not_to change(ActiveStorage::Attachment, :count)
    end
  end
end
