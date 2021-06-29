# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/dashboard_sections/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
  let!(:dashboard_section1) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:dashboard_section2) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:organization1) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
  let!(:chart1) { create(:chart, name: 'Chart1', dashboard_section_id: dashboard_section1.id) }

  let(:e_intervention_admin) { organization.e_intervention_admins.first }
  let(:organization_admin) { organization.organization_admins.first }

  let(:roles_organization) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin
    }
  end
  let(:roles_organization1) do
    {
      'organization_admin' => organization1.organization_admins.first,
      'e_intervention_admin' => organization1.e_intervention_admins.first
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organization_dashboard_section_path(organization.id, dashboard_section1.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_organization_dashboard_section_path(organization.id, dashboard_section1.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  shared_examples 'unpermitted user' do
    before { request }

    it 'returns proper error message' do
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper data' do
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
                  {
                    'id' => chart1.id,
                    'type' => 'chart'
                  }
                ]
              }
            }
          }
        )
      end

      it 'returns proper include' do
        expect(json_response['included'][0]).to include(
          {
            'id' => chart1.id,
            'type' => 'chart',
            'attributes' => {
              'name' => chart1.name,
              'description' => chart1.description,
              'chart_type' => chart1.chart_type,
              'status' => chart1.status,
              'position' => 1,
              'trend_line' => false,
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
      end

      it 'returns proper collection size' do
        expect(json_response.size).to eq(2)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when user is' do
      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          context 'refers to their organization' do
            let(:user) { roles_organization[role] }

            it_behaves_like 'permitted user'
          end

          context 'doesn\'t refer to other organization' do
            let(:user) { roles_organization1[role] }

            it_behaves_like 'unpermitted user'
          end
        end
      end
    end
  end

  context 'when user is not permitted' do
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
