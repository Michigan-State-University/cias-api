# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/report_templates/:report_template_id/sections/:id', type: :request do
  let(:request) do
    put v1_report_template_section_path(report_template_id: report_template.id, id: report_template_section.id),
        params: params, headers: headers
  end
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let!(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:params) do
      {
        section: {
          formula: 'var10 + var20'
        }
      }
    end

    it 'returns :ok status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'updates report template section with given attributes' do
      expect { request }.to avoid_changing(ReportTemplate::Section, :count)

      expect(report_template_section.reload).to have_attributes(
        formula: 'var10 + var20'
      )
    end
  end

  context 'when params are invalid' do
    context 'when section params are missing' do
      let(:params) { { section: {} } }

      it 'does not update the section, returns :bad_request status' do
        expect { request }.not_to change { report_template_section.reload.attributes }
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
      expect { request }.not_to change { report_template_section.reload.attributes }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
