# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/report_templates/sections/:section_id/variants', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let!(:report_template_section_variant1) do
    create(:report_template_section_variant, :with_image, report_template_section: report_template_section)
  end
  let!(:report_template_section_variant2) do
    create(:report_template_section_variant, :with_image, report_template_section: report_template_section)
  end

  before do
    get v1_report_template_section_variants_path(section_id: report_template_section.id),
        headers: headers
  end

  context 'when there are report template sections' do
    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns variants of the report template section' do
      expect(json_response['data']).to include(
        'id' => report_template_section_variant1.id.to_s,
        'type' => 'variant',
        'attributes' => include(
          'title' => report_template_section_variant1.title,
          'content' => report_template_section_variant1.content,
          'preview' => report_template_section_variant1.preview,
          'formula_match' => report_template_section_variant1.formula_match,
          'image_url' => include('logo.png'),
          'report_template_section_id' => report_template_section.id
        )
      ).and include(
        'id' => report_template_section_variant2.id.to_s,
        'type' => 'variant',
        'attributes' => include(
          'title' => report_template_section_variant2.title,
          'content' => report_template_section_variant2.content,
          'preview' => report_template_section_variant2.preview,
          'formula_match' => report_template_section_variant2.formula_match,
          'image_url' => include('logo.png'),
          'report_template_section_id' => report_template_section.id
        )
      )
    end
  end

  context 'when there are no variants of the report template section' do
    before do
      report_template_section.variants.destroy_all
      get v1_report_template_section_variants_path(section_id: report_template_section.id),
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
