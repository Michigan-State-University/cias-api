# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/report_templates/:report_template_id/generate_pdf_preview', type: :request do
  let(:request) do
    post v1_report_template_generate_pdf_preview_path(report_template_id: report_template.id),
         params: {}, headers: headers
  end
  let!(:report_template) { create(:report_template) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when report template id is valid' do
    it 'runs generate pdf preview job and returns :created status' do
      expect(ReportTemplates::GeneratePdfPreviewJob).to receive(:perform_later).with(
        report_template.id,
        user.id
      )

      request

      expect(response).to have_http_status(:created)
    end
  end

  context 'authorization' do
    %i[researcher participant guest].each do |role|
      context "when user is #{role}" do
        let!(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'user who is not able to generate report template pdf preview'
      end
    end
  end
end
