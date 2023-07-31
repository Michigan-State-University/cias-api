# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:session_id/report_template', type: :request do
  let(:request) do
    post v1_session_report_templates_path(session_id: session.id),
         params: params, headers: headers
  end
  let!(:session) { create(:session) }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:headers) { user.create_new_auth_token }

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
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

        context 'when name for report template is missing' do
          let(:params) do
            {
              report_template: {
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
              name: 'New Report 1',
              report_for: 'participant',
              summary: 'Your session summary',
              session_id: session.id,
              cover_letter_logo_type: 'report_logo'
            )
          end

          it 'changes number of last report template' do
            request
            expect(session.reload.last_report_template_number).to eq(1)
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
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
