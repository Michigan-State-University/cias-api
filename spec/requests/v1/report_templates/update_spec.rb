# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/sessions/:session_id/report_template/:id', type: :request do
  let(:request) do
    patch v1_session_report_template_path(session_id: session.id, id: report_template.id),
          params: params, headers: headers
  end
  let!(:report_template) { create(:report_template) }
  let(:session) { report_template.session }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:logo) { fixture_file_upload('images/logo.png', 'image/png') }

  context 'when params are valid' do
    let(:params) do
      {
        report_template: {
          name: 'New Report Template',
          report_for: 'participant',
          summary: 'Your session summary',
          logo: logo
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'updates report template with given attributes' do
      expect { request }.to change(ActiveStorage::Attachment, :count).by(1).and \
        change(ActiveStorage::Blob, :count).by(1).and \
          avoid_changing(ReportTemplate, :count)

      expect(ReportTemplate.last).to have_attributes(
        name: 'New Report Template',
        report_for: 'participant',
        summary: 'Your session summary'
      )
    end

    context 'logo is replaced' do
      before do
        report_template.update(logo: fixture_file_upload('images/logo.png'))
      end

      let(:old_logo) { report_template.logo }

      it 'updated report template attachment logo' do
        expect { request }.to change { ActiveStorage::Attachment.exists?(id: old_logo.id) }.from(true).to(false).and \
          avoid_changing { ActiveStorage::Attachment.count }

        expect(report_template.reload.logo).to be_present
      end
    end
  end

  context 'when params are invalid' do
    context 'when team params are missing' do
      let(:params) { { report_template: {} } }

      it 'does not create new team, returns :bad_request status' do
        expect { request }.not_to change(Team, :count)
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
      expect { request }.not_to change(Team, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
