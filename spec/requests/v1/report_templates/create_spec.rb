# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:session_id/report_template', type: :request do
  let(:request) do
    post v1_session_report_templates_path(session_id: session.id),
         params: params, headers: headers
  end
  let!(:session) { create(:session) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:params) do
      {
        report_template: {
          name: 'New Report Template',
          report_for: 'participant',
          summary: 'Your session summary'
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new report template with correct attributes' do
      expect { request }.to change(ReportTemplate, :count).by(1)

      expect(ReportTemplate.last).to have_attributes(
        name: 'New Report Template',
        report_for: 'participant',
        summary: 'Your session summary',
        session_id: session.id
      )
    end
  end

  context 'when params are invalid' do
    context 'when report template params are missing' do
      let(:params) { { report_template: {} } }

      it 'does not create new report template, returns :bad_request status' do
        expect { request }.not_to change(ReportTemplate, :count)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let(:params) do
      {
        report_template: {
          name: 'New Report Template',
          report_for: 'participant',
          summary: 'Your session summary'
        }
      }
    end

    it 'returns :forbidden status' do
      expect { request }.not_to change(ReportTemplate, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
