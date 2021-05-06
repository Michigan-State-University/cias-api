# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/organizations/:organization_id/dashboard_sections/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, :with_dashboard_section) }
  let(:dashboard_section) { organization.reporting_dashboard.dashboard_sections.first }

  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_organization_dashboard_section_path(organization.id, dashboard_section.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_organization_dashboard_section_path(organization.id, dashboard_section.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns correct status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'dashboard section is deleted' do
        expect(DashboardSection.find_by(id: dashboard_section.id)).to eq(nil)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when dashboard section id is invalid' do
        before do
          delete v1_organization_dashboard_section_path(organization.id, 'wrong id'), headers: headers
        end

        it 'error message is expected' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when user is e-intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[organization_admin health_system_admin health_clinic_admin team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
