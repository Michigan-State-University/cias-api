# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/report_templates/:report_template_id/sections', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section1) { create(:report_template_section, report_template: report_template) }
  let!(:report_template_section2) { create(:report_template_section, report_template: report_template) }

  before do
    get v1_report_template_sections_path(report_template_id: report_template.id),
        headers: headers
  end

  context 'when there are report template sections' do
    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns list of report template sections' do
      expect(json_response['data']).to include(
        'id' => report_template_section1.id.to_s,
        'type' => 'section',
        'attributes' => include(
          'formula' => report_template_section1.formula,
          'report_template_id' => report_template.id
        )
      ).and include(
        'id' => report_template_section2.id.to_s,
        'type' => 'section',
        'attributes' => include(
          'formula' => report_template_section2.formula,
          'report_template_id' => report_template.id
        )
      )
    end
  end

  context 'when there are no report template sections' do
    before do
      report_template.sections.destroy_all
      get v1_report_template_sections_path(report_template_id: report_template.id),
          headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'response should be empty' do
      expect(json_response['data']).to be_empty
    end
  end
end
