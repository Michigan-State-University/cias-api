# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/report_templates/sections/:section_id/variants', type: :request do
  let(:request) do
    post v1_report_template_section_variants_path(section_id: report_template_section.id),
         params: params, headers: headers
  end
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:image) { fixture_file_upload('images/logo.png', 'image/png') }

  context 'when params are valid' do
    let(:params) do
      {
        variant: {
          preview: true,
          formula_match: '=10',
          title: 'Variant 1',
          content: 'This is content for variant 1',
          image: image
        }
      }
    end
    let(:new_section_variant) { ReportTemplate::Section::Variant.last }

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new report template section variant with correct attributes' do
      expect { request }.to change(ReportTemplate::Section::Variant, :count).by(1).and \
        change(ActiveStorage::Attachment, :count).by(1)

      expect(new_section_variant).to have_attributes(
        preview: true,
        formula_match: '=10',
        title: 'Variant 1',
        content: 'This is content for variant 1',
        report_template_section_id: report_template_section.id
      )
    end
  end

  context 'when params are invalid' do
    context 'when variant params are missing' do
      let(:params) { { variant: {} } }

      it 'does not create new section veriant, returns :bad_request status' do
        expect { request }.not_to change(ReportTemplate::Section::Variant, :count)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let(:params) do
      {
        variant: {
          preview: true,
          formula_match: '=10',
          title: 'Variant 1',
          content: 'This is content for variant 1'
        }
      }
    end

    it 'does not create new variant, returns :forbidden status' do
      expect { request }.not_to change(ReportTemplate::Section::Variant, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
