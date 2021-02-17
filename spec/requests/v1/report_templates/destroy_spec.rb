# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sessions/:session_id/report_template/:id', type: :request do
  let(:request) do
    delete v1_session_report_template_path(session_id: session.id, id: report_template.id),
           params: {}, headers: headers
  end
  let!(:report_template) { create(:report_template, :with_logo) }
  let(:session) { report_template.session }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'removes report template and it\'s attachments' do
      expect { request }.to change(ActiveStorage::Attachment, :count).by(-1).and \
        change(ReportTemplate, :count).by(-1)

      expect(ReportTemplate.exists?(report_template.id)).to be false
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }

    it 'returns :forbidden status' do
      expect { request }.not_to change(ReportTemplate, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
