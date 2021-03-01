# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/report_templates/sections/:section_id/variants/:id', type: :request do
  let(:request) do
    put v1_report_template_section_variant_path(
      section_id: report_template_section.id,
      id: report_template_section_variant.id
    ), params: params, headers: headers
  end
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let!(:report_template_section_variant) do
    create(:report_template_section_variant, report_template_section: report_template_section)
  end
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

    it 'returns :ok status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'updates report template section variant with given attributes' do
      expect { request }.to avoid_changing(ReportTemplate::Section::Variant, :count).and \
        change(ActiveStorage::Attachment, :count).and \
          change(ActiveStorage::Blob, :count)

      expect(report_template_section_variant.reload).to have_attributes(
        preview: true,
        formula_match: '=10',
        title: 'Variant 1',
        content: 'This is content for variant 1',
        report_template_section_id: report_template_section.id
      )

      expect(report_template_section_variant.image).to be_present
    end

    context 'other variant in the section is set to preview' do
      let!(:variant_to_preview) do
        create(:report_template_section_variant, preview: true,
                                                 report_template_section_id: report_template_section.id)
      end

      it 'set other variants in the section to not preview' do
        expect { request }.to change { variant_to_preview.reload.preview }.from(true).to(false).and \
          change { report_template_section_variant.reload.preview }.from(false).to(true)
      end
    end
  end

  context 'when params are invalid' do
    context 'when section params are missing' do
      let(:params) { { variant: {} } }

      it 'does not update the variant, returns :bad_request status' do
        expect { request }.not_to change { report_template_section_variant.reload.attributes }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let(:params) do
      {
        section: {
          formula: 'var13'
        }
      }
    end

    it 'does not update the section, returns :forbidden status' do
      expect { request }.not_to change { report_template_section_variant.reload.attributes }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
