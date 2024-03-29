# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:session_id/report_templates/:report_template_id/duplicate', type: :request do
  let(:request) do
    post v1_session_report_template_duplicate_path(session_id: session.id, report_template_id: report_template.id),
         params: params, headers: headers
  end

  let(:intervention) { create(:intervention, user: user) }
  let(:session) { create(:session, :with_report_templates, intervention: intervention, name: 'Pierwsza') }
  let(:session2) { create(:session, name: 'Second', intervention: intervention) }
  let!(:report_template) { session.report_templates.last }
  let(:headers) { user.create_new_auth_token }
  let!(:user) { create(:user, :confirmed, :researcher) }
  let(:params) { {} }

  context 'when the owner do it' do
    it 'return correct status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'created a new report' do
      expect { request }.to change(ReportTemplate, :count).by(1)
    end

    it 'selected session has 3 attachments' do
      request
      expect(session.report_templates.count).to be(3)
    end

    context 'when intervention has collaborators and current user isn\'t current editor' do
      let(:intervention) { create(:intervention, :with_collaborators, current_editor: create(:user, :researcher, :confirmed)) }

      it 'return forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when passed session_id is wrong' do
      let(:params) { { report_template: { session_id: 'not_existing_id' } } }

      it 'return not found' do
        request
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'duplicate report to other session in the same intervention' do
      let(:params) { { report_template: { session_id: session2.id } } }

      it 'session should have a report' do
        request
        expect(session2.report_templates.count).to be(1)
      end
    end

    context 'duplicate report to other session in the another intervention' do
      let(:another_session) { create(:session) }
      let(:params) { { report_template: { session_id: another_session.id } } }

      it 'return created' do
        request
        expect(response).to have_http_status(:created)
      end

      context 'when session belongs to intervention with collaborators' do
        let(:another_session) { create(:session, intervention: create(:intervention, :with_collaborators)) }

        it 'return created' do
          request
          expect(response).to have_http_status(:created)
        end
      end
    end
  end
end
