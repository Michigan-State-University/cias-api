# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/report_templates/:report_template_id/sections/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section1) { create(:report_template_section, report_template: report_template) }
  let!(:report_template_section2) { create(:report_template_section, report_template: report_template) }

  before do
    get v1_report_template_section_path(report_template_id: report_template.id, id: report_template_section1.id),
        headers: headers
  end

  context 'when there are report template sections' do
    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns report template section' do
      expect(json_response['data']).to include(
        'id' => report_template_section1.id.to_s,
        'type' => 'section',
        'attributes' => include(
          'formula' => report_template_section1.formula,
          'report_template_id' => report_template.id
        )
      )

      expect(json_response['data']).to be_an_instance_of Hash
    end
  end

  context 'when there is no section with given id' do
    before do
      get v1_report_template_section_path(report_template_id: report_template.id, id: 'non-existing'),
          headers: headers
    end

    it 'has correct http code :not_found' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
