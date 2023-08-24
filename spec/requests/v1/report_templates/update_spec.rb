# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/sessions/:session_id/report_template/:id', type: :request do
  let(:request) do
    patch v1_session_report_template_path(session_id: session.id, id: report_template.id),
          params: params, headers: headers
  end
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:report_template) { create(:report_template, session: session) }
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
  let(:logo) { FactoryHelpers.upload_file('spec/fixtures/images/logo.png', 'image/png', true) }

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when params are valid' do
        let(:params) do
          {
            report_template: {
              name: 'New Report Template',
              report_for: 'participant',
              summary: 'Your session summary',
              logo: logo,
              duplicated_from_other_session_warning_dismissed: true
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
            summary: 'Your session summary',
            duplicated_from_other_session_warning_dismissed: true
          )
        end

        context 'logo is replaced' do
          before do
            report_template.update(logo: FactoryHelpers.upload_file('spec/fixtures/images/logo.png', 'image/png', true))
          end

          let(:old_logo) { report_template.logo }

          it 'updated report template attachment logo' do
            expect { request }.to change {
                                    ActiveStorage::Attachment.exists?(id: old_logo.id)
                                  }.from(true).to(false).and \
                                    avoid_changing { ActiveStorage::Attachment.count }

            expect(report_template.reload.logo).to be_present
          end
        end
      end

      context 'when params are invalid' do
        context 'when report template params are missing' do
          let(:params) { { report_template: {} } }

          it 'does not update report template, returns :bad_request status' do
            expect { request }.not_to change { report_template.reload.attributes }
            expect(response).to have_http_status(:bad_request)
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
      expect { request }.not_to change { report_template.reload.attributes }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'collaboration mode' do
    let(:params) do
      {
        report_template: {
          name: 'New Report Template'
        }
      }
    end

    it_behaves_like 'collaboration mode - only one editor at the same time'
  end
end
