# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/report_templates/sections/:section_id/variants', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let!(:report_template_section_variant) do
    create(:report_template_section_variant, :with_image, report_template_section: report_template_section)
  end

  before do
    get v1_report_template_section_variant_path(
      section_id: report_template_section.id,
      id: report_template_section_variant.id
    ), headers: headers
  end

  context 'when there are report template sections' do
    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns report template section' do
      expect(json_response['data']).to include(
        'id' => report_template_section_variant.id.to_s,
        'type' => 'variant',
        'attributes' => include(
          'title' => report_template_section_variant.title,
          'content' => report_template_section_variant.content,
          'preview' => report_template_section_variant.preview,
          'formula_match' => report_template_section_variant.formula_match,
          'image_url' => include('logo.png'),
          'report_template_section_id' => report_template_section.id
        )
      )

      expect(json_response['data']).to be_an_instance_of Hash
    end
  end

  context 'when there is no section with given id' do
    before do
      get v1_report_template_section_variant_path(
        section_id: report_template_section.id,
        id: 'invalid'
      ), headers: headers
    end

    it 'has correct http code :not_found' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
