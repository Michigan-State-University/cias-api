# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sessions/:session_id/report_template/:id', type: :request do
  let(:request) do
    delete v1_session_report_template_path(session_id: session.id, id: report_template.id),
           params: {}, headers: headers
  end
  let!(:report_template) { create(:report_template, :with_logo) }
  let(:session) { report_template.session }
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

  context 'admin has one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when params are valid' do
        it 'returns :no_content status' do
          request
          expect(response).to have_http_status(:no_content)
        end

        it 'removes report template and it\'s attachments' do
          expect { request }.to change(ActiveStorage::Attachment, :count).by(-1).and \
            change(ReportTemplate, :count).by(-1)

          expect(ReportTemplate.exists?(report_template.id)).to be false
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

    it 'returns :forbidden status' do
      expect { request }.not_to change(ReportTemplate, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
