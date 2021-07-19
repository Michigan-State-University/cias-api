# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/charts/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:chart) do
    create(:chart, name: 'Chart', description: 'Some description', dashboard_section_id: dashboard_section.id)
  end
  let!(:published_chart) do
    create(:chart, name: 'Chart', description: 'Old description', status: :published,
                   dashboard_section_id: dashboard_section.id)
  end
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      chart: {
        name: 'New name',
        description: 'New description',
        chart_type: 'pie_chart',
        status: 'published'
      }
    }
  end
  let(:request) { patch v1_chart_path(chart.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_chart_path(chart.id) }

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
        expect(response).to have_http_status(:ok)
      end

      it 'returns proper data' do
        expect(json_response['data']).to include(
          {
            'id' => chart.id.to_s,
            'type' => 'chart',
            'attributes' => {
              'name' => 'New name',
              'description' => 'New description',
              'status' => 'published',
              'trend_line' => false,
              'chart_type' => 'pie_chart',
              'position' => 1,
              'formula' => {
                'payload' => '',
                'patterns' => [{ 'color' => '#C766EA',
                                 'label' => 'Matched',
                                 'match' => '' }],
                'default_pattern' => {
                  'color' => '#E2B1F4',
                  'label' => 'NotMatched'
                }
              },
              'dashboard_section_id' => dashboard_section.id,
              'published_at' => nil
            }
          }
        )
      end

      it 'in database is correct data' do
        expect(Chart.find(chart.id).status).to eq('published')
      end

      context 'when user want to change published chart' do
        let(:params) do
          {
            chart: {
              name: 'New name',
              description: 'New description',
              chart_type: 'pie_chart',
              status: 'draft'
            }
          }
        end

        let(:request) { patch v1_chart_path(published_chart.id), params: params, headers: headers }

        it 'not change the data' do
          expect(Chart.find(published_chart.id).status).to eq('published')
          expect(Chart.find(published_chart.id).description).to eq('Old description')
        end
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when admin has multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[guest admin participant]) }

      it_behaves_like 'permitted user'
    end

    context 'when user is e-intervention_admin' do
      let(:user) { e_intervention_admin }

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

    %i[health_system_admin organization_admin team_admin researcher participant guest
       health_clinic_admin].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it_behaves_like 'preview user'
    end
  end
end
