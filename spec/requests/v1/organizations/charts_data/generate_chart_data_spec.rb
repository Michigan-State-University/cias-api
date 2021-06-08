# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/charts_data/generate', type: :request do
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let!(:dashboard_sections) { create(:dashboard_section, name: 'Dashboard section', reporting_dashboard: reporting_dashboard) }

  let(:admin) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:user) { admin }
  let(:organization_admin) { organization.organization_admins.first }
  let(:e_intervention_admin) { organization.e_intervention_admins.first }
  let(:health_system_amin) { health_system.health_system_admins.first }
  let(:health_clinic_admin) { health_clinic.user_health_clinics.first.user }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }

  let(:roles) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin,
      'health_system_admin' => health_system_amin,
      'health_clinic_admin' => health_clinic_admin,
      'admin' => admin,
      'researcher' => researcher,
      'participant' => participant
    }
  end

  let!(:chart1) { create(:chart, name: 'chart1', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }
  let!(:chart2) { create(:chart, name: 'chart2', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }
  let!(:bar_chart) { create(:chart, name: 'chart3', dashboard_section: dashboard_sections, chart_type: 'bar_chart') }

  let!(:chart_statistic1) { create(:chart_statistic, label: 'label1', organization: organization, health_system: health_system, chart: chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_statistic2) { create(:chart_statistic, label: 'label1', organization: organization, health_system: health_system, chart: chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_statistic3) { create(:chart_statistic, label: 'label1', organization: organization, health_system: health_system, chart: chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_statistic4) { create(:chart_statistic, label: 'label1', organization: organization, health_system: health_system, chart: chart1, health_clinic: health_clinic, created_at: 1.month.ago) }
  let!(:chart_statistic5) { create(:chart_statistic, label: 'other1', organization: organization, health_system: health_system, chart: chart1, health_clinic: health_clinic, created_at: 1.month.ago) }
  let!(:chart_statistic6) { create(:chart_statistic, label: 'label2', organization: organization, health_system: health_system, chart: chart2, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_statistic7) { create(:chart_statistic, label: 'other2', organization: organization, health_system: health_system, chart: chart2, health_clinic: health_clinic, created_at: 3.months.ago) }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      charts_data: {
        clinic_ids: [health_clinic.id]
      }
    }
  end

  let(:request) { get v1_organization_chart_data_generate_path(organization_id: organization.id, chart_id: chart1.id), headers: headers, params: params }

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper data' do
        expect(json_response).to include({
                                           'chart_id' => chart1.id,
                                           'chart_data' => include(
                                             {
                                               'label' => 'label1',
                                               'value' => 4
                                             },
                                             {
                                               'label' => 'other1',
                                               'value' => 1
                                             }
                                           )
                                         })
      end

      context 'return data from a specific period of time' do
        let(:params) do
          {
            charts_data: {
              clinic_ids: [health_clinic.id],
              start_date: 1.month.ago,
              end_date: Time.zone.now
            }
          }
        end

        it 'return correct data' do
          expect(json_response).to include({
                                             'chart_id' => chart1.id,
                                             'chart_data' => include(
                                               {
                                                 'label' => 'label1',
                                                 'value' => 1
                                               },
                                               {
                                                 'label' => 'other1',
                                                 'value' => 1
                                               }
                                             )
                                           })
        end
      end

      context 'when params are INVALID' do
        let(:params) do
          {
            charts_data: {
              clinic_ids: ['wrong_clinic_id']
            }
          }
        end

        it 'return empty list' do
          expect(json_response).to eq(nil)
        end
      end
    end

    context 'when user is' do
      %w[admin organization_admin e_intervention_admin health_clinic_admin admin].each do |role|
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

    %i[researcher participant].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user belongs to other organization' do
      let!(:organization2) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Other Organization') }
      let(:other_organization_admin) { organization2.organization_admins.first }

      let(:headers) { other_organization_admin.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to include('Couldn\'t find Organization with')
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
