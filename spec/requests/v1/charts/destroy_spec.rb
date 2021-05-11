# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/charts/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:other_organization) { create(:organization, :with_e_intervention_admin, name: 'Other Organization') }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:other_dashboard_section) { create(:dashboard_section, reporting_dashboard: other_organization.reporting_dashboard) }
  let!(:chart) { create(:chart, name: 'Chart1', dashboard_section_id: dashboard_section.id) }
  let!(:other_chart) { create(:chart, name: 'Chart2', dashboard_section_id: dashboard_section.id) }
  let!(:chart_in_other_organization) { create(:chart, name: 'Chart3', dashboard_section_id: other_dashboard_section.id) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:other_e_intervention_admin) { other_organization.e_intervention_admins.first }

  let(:headers) { user.create_new_auth_token }

  let(:request) { delete v1_chart_path(chart.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_chart_path(chart.id) }

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

      it 'health clinic is deleted' do
        expect(Chart.find_by(id: chart.id)).to eq(nil)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when health system id is invalid' do
        before do
          delete v1_chart_path('wrong_id'), headers: headers
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

    %i[health_system_admin organization_admin team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when e-intervention admin belongs to other organization' do
      let(:user) { other_e_intervention_admin }
      let(:headers) { user.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to include('Couldn\'t find Chart with')
      end
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it_behaves_like 'preview user'
    end
  end
end
