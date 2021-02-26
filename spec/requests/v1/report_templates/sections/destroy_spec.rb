# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/report_templates/:report_template_id/sections/:id', type: :request do
  let(:request) do
    delete v1_report_template_section_path(report_template_id: report_template.id, id: report_template_section.id),
           params: {}, headers: headers
  end
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'removes report template section' do
      expect { request }.to change(ReportTemplate::Section, :count).by(-1)

      expect(ReportTemplate::Section.exists?(report_template.id)).to be false
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }

    it 'does not remove report template section, returns :forbidden status' do
      expect { request }.not_to change(ReportTemplate::Section, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
