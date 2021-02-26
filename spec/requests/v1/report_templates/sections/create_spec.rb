# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/report_templates/:report_template_id/sections', type: :request do
  let(:request) do
    post v1_report_template_sections_path(report_template_id: report_template.id),
         params: params, headers: headers
  end
  let!(:session) { create(:session) }
  let!(:report_template) { create(:report_template, session: session) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:params) do
      {
        section: {
          formula: 'var1 + var2'
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new report template with correct attributes' do
      expect { request }.to change(ReportTemplate::Section, :count).by(1)

      expect(ReportTemplate::Section.last).to have_attributes(
        formula: 'var1 + var2',
        report_template_id: report_template.id
      )
    end
  end

  context 'when params are invalid' do
    context 'when section params are missing' do
      let(:params) { { section: {} } }

      it 'does not create new section, returns :bad_request status' do
        expect { request }.not_to change(ReportTemplate::Section, :count)
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
          formula: 'var1'
        }
      }
    end

    it 'does not create new section, returns :forbidden status' do
      expect { request }.not_to change(ReportTemplate::Section, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
