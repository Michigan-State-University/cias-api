# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/charts_data/generate', type: :request do
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:reporting_dashboard) { organization.reporting_dashboard }
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

  let!(:pie_chart) { create(:chart, name: 'pie_chart', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'published') }
  let!(:bar_chart) { create(:chart, name: 'bar_chart', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }
  let!(:percentage_bar_chart) do
    create(:chart, name: 'percentage_bar_chart', dashboard_section: dashboard_sections, chart_type: 'percentage_bar_chart', status: 'published')
  end

  let!(:chart_matched_statistic1) do
    create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: pie_chart,
                                      health_clinic: health_clinic, filled_at: 2.months.ago)
  end
  let!(:chart_not_matched_statistic1) do
    create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: pie_chart,
                                     health_clinic: health_clinic, filled_at: 2.months.ago)
  end
  let!(:chart_matched_statistic2) do
    create_list(:chart_statistic, 3, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart, health_clinic: health_clinic,
                                     filled_at: 3.months.ago)
  end
  let!(:chart_not_matched_statistic2) do
    create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart,
                                     health_clinic: health_clinic, filled_at: 3.months.ago)
  end
  let!(:chart_matched_statistic3) do
    create_list(:chart_statistic, 3, label: 'Matched', organization: organization, health_system: health_system, chart: percentage_bar_chart,
                                     health_clinic: health_clinic, filled_at: 1.month.ago)
  end
  let!(:chart_not_matched_statistic3) do
    create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: percentage_bar_chart,
                                     health_clinic: health_clinic, filled_at: 1.month.ago)
  end

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      clinic_ids: [health_clinic.id],
      statuses: ['published']
    }
  end

  let(:request) { get v1_organization_charts_data_generate_path(organization.id), headers: headers, params: params }

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper collection size' do
        expect(json_response['data_for_charts'].size).to eq(3)
      end

      it 'return proper data' do
        expect(json_response['data_for_charts']).to include(
          {
            'chart_id' => percentage_bar_chart.id,
            'data' => [
              {
                'label' => 1.month.ago.strftime('%B %Y'),
                'value' => 37.5,
                'color' => '#C766EA',
                'population' => 8
              }
            ],
            'population' => 8,
            'dashboard_section_id' => percentage_bar_chart.dashboard_section_id
          },
          {
            'chart_id' => bar_chart.id,
            'data' => [
              {
                'label' => 3.months.ago.strftime('%B %Y'),
                'value' => 3,
                'color' => '#C766EA',
                'notMatchedValue' => 5
              }
            ],
            'population' => 8,
            'dashboard_section_id' => bar_chart.dashboard_section_id
          },
          {
            'chart_id' => pie_chart.id,
            'data' => include(
              {
                'label' => 'Matched',
                'value' => 10,
                'color' => '#C766EA'
              },
              {
                'label' => 'NotMatched',
                'value' => 5,
                'color' => '#E2B1F4'
              }
            ),
            'population' => 15,
            'dashboard_section_id' => pie_chart.dashboard_section_id
          }
        )
      end

      context 'when params are INVALID' do
        let(:params) do
          {
            clinic_ids: ['wrong_clinic_id'],
            statuses: ['published']
          }
        end

        it 'return empty list' do
          expect(json_response['data_for_charts']).to include(
            {
              'chart_id' => pie_chart.id,
              'data' => [],
              'population' => 0,
              'dashboard_section_id' => pie_chart.dashboard_section_id
            },
            {
              'chart_id' => bar_chart.id,
              'data' => [],
              'population' => 0,
              'dashboard_section_id' => bar_chart.dashboard_section_id
            },
            {
              'chart_id' => percentage_bar_chart.id,
              'data' => [],
              'population' => 0,
              'dashboard_section_id' => percentage_bar_chart.dashboard_section_id
            }
          )
        end
      end

      context 'with draft chart' do
        let!(:draft_pie_chart) { create(:chart, name: 'pie_chart', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'data_collection') }
        let!(:chart_matched_statistic1) do
          create_list(:chart_statistic, 3, label: 'Matched', organization: organization, health_system: health_system, chart: draft_pie_chart,
                                           health_clinic: health_clinic, filled_at: 2.months.ago)
        end
        let!(:chart_not_matched_statistic1) do
          create_list(:chart_statistic, 2, label: 'NotMatched', organization: organization, health_system: health_system, chart: draft_pie_chart,
                                           health_clinic: health_clinic, filled_at: 2.months.ago)
        end

        let(:params) do
          {
            clinic_ids: [health_clinic.id],
            statuses: %w[data_collection published]
          }
        end

        it 'returns proper collection size' do
          expect(json_response['data_for_charts'].size).to eq(4)
        end

        it 'return proper data' do
          expect(json_response['data_for_charts']).to include(
            {
              'chart_id' => draft_pie_chart.id,
              'data' => include(
                {
                  'label' => 'Matched',
                  'value' => 3,
                  'color' => '#C766EA'
                },
                {
                  'label' => 'NotMatched',
                  'value' => 2,
                  'color' => '#E2B1F4'
                }
              ),
              'population' => 5,
              'dashboard_section_id' => draft_pie_chart.dashboard_section_id
            }
          )
        end
      end
    end

    context 'when user is' do
      %w[admin organization_admin e_intervention_admin health_clinic_admin].each do |role|
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

    context 'when user is health_clinic_admin and one health clinic invitation is not accepted' do
      let(:headers) { health_clinic_admin.create_new_auth_token }
      let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }

      let!(:chart_hc2) { create(:chart, name: 'chart_hc2', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'published') }
      let!(:chart_matched_statistic_hc2) do
        create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: chart_hc2,
                                          health_clinic: health_clinic2, filled_at: 2.months.ago)
      end
      let!(:chart_not_matched_statistic_hc2) do
        create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: chart_hc2,
                                         health_clinic: health_clinic2, filled_at: 3.months.ago)
      end

      before do
        health_clinic2.user_health_clinics << UserHealthClinic.create!(user: health_clinic_admin, health_clinic: health_clinic2)
        HealthClinicInvitation.create!(user: health_clinic_admin, health_clinic: health_clinic2)
        request
      end

      it 'returns proper collection size' do
        expect(json_response['data_for_charts'].size).to eq(4)
      end

      it 'return proper data' do
        expect(json_response['data_for_charts']).to include(
          {
            'chart_id' => percentage_bar_chart.id,
            'data' => [
              {
                'label' => 1.month.ago.strftime('%B %Y'),
                'value' => 37.5,
                'color' => '#C766EA',
                'population' => 8
              }
            ],
            'population' => 8,
            'dashboard_section_id' => percentage_bar_chart.dashboard_section_id
          },
          {
            'chart_id' => bar_chart.id,
            'data' => [
              {
                'label' => 3.months.ago.strftime('%B %Y'),
                'value' => 3,
                'color' => '#C766EA',
                'notMatchedValue' => 5
              }
            ],
            'population' => 8,
            'dashboard_section_id' => bar_chart.dashboard_section_id
          },
          {
            'chart_id' => pie_chart.id,
            'data' => include(
              {
                'label' => 'Matched',
                'value' => 10,
                'color' => '#C766EA'
              },
              {
                'label' => 'NotMatched',
                'value' => 5,
                'color' => '#E2B1F4'
              }
            ),
            'population' => 15,
            'dashboard_section_id' => pie_chart.dashboard_section_id
          },
          {
            'chart_id' => chart_hc2.id,
            'data' => [],
            'population' => 0,
            'dashboard_section_id' => chart_hc2.dashboard_section_id
          }
        )
      end
    end
  end
end
