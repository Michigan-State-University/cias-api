# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/dashboard_sections', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, :with_organization_admin) }
  let!(:dashboard_section_1) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:dashboard_section_2) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:dashboard_section_3) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:chart) { create(:chart, name: 'Some chart', description: 'Some description', dashboard_section_id: dashboard_section_1.id) }

  let!(:organization_admin) { organization.organization_admins.first }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }

  let(:roles) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin,
      'admin' => admin
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organization_dashboard_sections_path(organization.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_organization_dashboard_sections_path(organization.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper collection size' do
        expect(json_response['data'].size).to eq(3)
      end

      it 'returns proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => dashboard_section_1.id,
            'type' => 'dashboard_section',
            'attributes' => {
              'name' => dashboard_section_1.name,
              'description' => dashboard_section_1.description,
              'reporting_dashboard_id' => organization.reporting_dashboard.id,
              'organization_id' => organization.id
            },
            'relationships' => {
              'charts' => {
                'data' => [
                  'id' => chart.id,
                  'type' => 'chart'
                ]
              }
            }
          },
          {
            'id' => dashboard_section_2.id,
            'type' => 'dashboard_section',
            'attributes' => {
              'name' => dashboard_section_2.name,
              'description' => dashboard_section_2.description,
              'reporting_dashboard_id' => organization.reporting_dashboard.id,
              'organization_id' => organization.id
            },
            'relationships' => {
              'charts' => {
                'data' => []
              }
            }
          },
          {
            'id' => dashboard_section_3.id,
            'type' => 'dashboard_section',
            'attributes' => {
              'name' => dashboard_section_3.name,
              'description' => dashboard_section_3.description,
              'reporting_dashboard_id' => organization.reporting_dashboard.id,
              'organization_id' => organization.id
            },
            'relationships' => {
              'charts' => {
                'data' => []
              }
            }
          }
        )
      end
    end

    context 'when user is' do
      %w[admin organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          let(:user) { roles[role] }

          it_behaves_like 'permitted user'
        end
      end
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[health_system_admin health_clinic_admin team_admin researcher participant guest].each do |role|
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
