# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/dashboard_sections', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, :with_organization_admin) }
  let!(:dashboard_section1) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:dashboard_section2) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard, position: 2) }
  let!(:dashboard_section3) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard, position: 3) }
  let!(:chart1) { create(:chart, name: 'Some chart 1', description: 'Some description 1', dashboard_section_id: dashboard_section1.id, status: 'published') }
  let!(:chart2) { create(:chart, name: 'Some chart 2', description: 'Some description 2', dashboard_section_id: dashboard_section2.id, position: 2) }

  let!(:organization_admin) { organization.organization_admins.first }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }

  let(:roles) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin,
      'admin' => admin
    }
  end
  let(:params) { {} }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organization_dashboard_sections_path(organization.id), headers: headers, params: params }

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
                                             'id' => dashboard_section1.id,
                                             'type' => 'dashboard_section',
                                             'attributes' => {
                                               'name' => dashboard_section1.name,
                                               'description' => dashboard_section1.description,
                                               'reporting_dashboard_id' => organization.reporting_dashboard.id,
                                               'organization_id' => organization.id,
                                               'position' => 1
                                             },
                                             'relationships' => {
                                               'charts' => {
                                                 'data' => [
                                                   { 'id' => chart1.id,
                                                     'type' => 'chart' }
                                                 ]
                                               }
                                             }
                                           },
                                           {
                                             'id' => dashboard_section2.id,
                                             'type' => 'dashboard_section',
                                             'attributes' => {
                                               'name' => dashboard_section2.name,
                                               'description' => dashboard_section2.description,
                                               'reporting_dashboard_id' => organization.reporting_dashboard.id,
                                               'organization_id' => organization.id,
                                               'position' => 2
                                             },
                                             'relationships' => {
                                               'charts' => {
                                                 'data' => [
                                                   {
                                                     'id' => chart2.id,
                                                     'type' => 'chart'
                                                   }
                                                 ]
                                               }
                                             }
                                           },
                                           {
                                             'id' => dashboard_section3.id,
                                             'type' => 'dashboard_section',
                                             'attributes' => {
                                               'name' => dashboard_section3.name,
                                               'description' => dashboard_section3.description,
                                               'reporting_dashboard_id' => organization.reporting_dashboard.id,
                                               'organization_id' => organization.id,
                                               'position' => 3
                                             },
                                             'relationships' => {
                                               'charts' => {
                                                 'data' => []
                                               }
                                             }
                                           }
                                         )
      end

      it 'returns proper included data' do
        expect(json_response['included'][0]).to include(
                                                  {
                                                    'id' => chart1.id,
                                                    'type' => 'chart',
                                                    'attributes' => {
                                                      'name' => chart1.name,
                                                      'description' => chart1.description,
                                                      'chart_type' => chart1.chart_type,
                                                      'status' => chart1.status,
                                                      'trend_line' => false,
                                                      'position' => 1,
                                                      'formula' => {
                                                        'payload' => '',
                                                        'patterns' => [
                                                          {
                                                            'color' => '#C766EA',
                                                            'label' => 'Matched',
                                                            'match' => ''
                                                          }
                                                        ],
                                                        'default_pattern' => {
                                                          'color' => '#E2B1F4',
                                                          'label' => 'NotMatched'
                                                        }
                                                      },
                                                      'dashboard_section_id' => chart1.dashboard_section_id,
                                                      'published_at' => nil
                                                    }
                                                  }
                                                )

        expect(json_response['included'][1]).to include(
                                                  {
                                                    'id' => chart2.id,
                                                    'type' => 'chart',
                                                    'attributes' => {
                                                      'name' => chart2.name,
                                                      'description' => chart2.description,
                                                      'chart_type' => chart2.chart_type,
                                                      'status' => chart2.status,
                                                      'trend_line' => false,
                                                      'position' => 2,
                                                      'formula' => {
                                                        'payload' => '',
                                                        'patterns' => [
                                                          {
                                                            'color' => '#C766EA',
                                                            'label' => 'Matched',
                                                            'match' => ''
                                                          }
                                                        ],
                                                        'default_pattern' => {
                                                          'color' => '#E2B1F4',
                                                          'label' => 'NotMatched'
                                                        }
                                                      },
                                                      'dashboard_section_id' => chart2.dashboard_section_id,
                                                      'published_at' => nil
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

  context 'when user accesses dashboard in dashboard view' do
    let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
    let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, health_system: health_system) }
    let(:health_clinic_admin) { health_clinic.user_health_clinics.first.user }
    let(:health_system_admin) { health_system.health_system_admins.first }
    let(:params) { { published: true } }

    let(:roles) do
      {
        'organization_admin' => organization_admin,
        'health_system_admin' => health_system_admin,
        'health_clinic_admin' => health_clinic_admin
      }
    end

    context 'when user is' do
      %w[organization_admin health_system_admin health_clinic_admin].each do |role|
        context role.to_s do
          let(:user) { roles[role] }

          before { request }

          it 'returns correct dashboard sections size' do
            expect(json_response['data'].size).to eq(1)
          end

          it 'returns correct data' do
            expect(json_response['data'][0]).to include(
                                                  {
                                                    'id' => dashboard_section1.id,
                                                    'type' => 'dashboard_section',
                                                    'attributes' => {
                                                      'name' => dashboard_section1.name,
                                                      'description' => dashboard_section1.description,
                                                      'reporting_dashboard_id' => organization.reporting_dashboard.id,
                                                      'organization_id' => organization.id,
                                                      'position' => 1,
                                                      'charts' => [include('id' => chart1.id, 'status' => 'published')]
                                                    }
                                                  }
                                                )
          end
        end
      end
    end
  end
end
