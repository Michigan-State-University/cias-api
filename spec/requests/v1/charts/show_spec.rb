# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/charts/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) do
    create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health')
  end
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:chart) do
    create(:chart, name: 'Chart', description: 'Some description', dashboard_section_id: dashboard_section.id)
  end
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_chart_path(chart.id), headers: headers }

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

      it 'returns proper data' do
        expect(json_response['data']).to include(
          {
            'id' => chart.id.to_s,
            'type' => 'chart',
            'attributes' => {
              'name' => chart.name,
              'description' => chart.description,
              'status' => 'draft',
              'trend_line' => false,
              'chart_type' => 'bar_chart',
              'position' => 1,
              'formula' => {
                'payload' => '',
                'patterns' => [{ 'color' => '#C766EA',
                                 'label' => 'Matched',
                                 'match' => '' }],
                'default_pattern' => {
                  'color' => '#E2B1F4',
                  'label' => 'NotMatched'
                },
                'min_answered_variables' => 0,
                'positive_despite_missing_data' => false
              },
              'formula_variable_count' => 0,
              'regenerating' => false,
              'dashboard_section_id' => dashboard_section.id,
              'date_range_start' => nil,
              'date_range_end' => nil,
              'interval_type' => 'monthly',
              'published_at' => nil
            }
          }
        )
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

    %i[team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end
  end

  # The frontend polls this endpoint to decide when to re-enable the regenerate button, so the
  # attribute has to flip both ways — `false` is asserted in the permitted-user block above.
  context 'when the chart is being regenerated' do
    before do
      chart.update!(regenerating_since: 1.minute.ago)
      request
    end

    it 'reports the in-progress state' do
      expect(json_response['data']['attributes']['regenerating']).to be(true)
    end
  end

  context 'when the regeneration lock has outlived the TTL' do
    before do
      chart.update!(regenerating_since: (V1::ChartStatistics::CreateForUserSessions::LOCK_TTL + 1.minute).ago)
      request
    end

    it 'reports it as idle again, matching what the service would do with that lock' do
      expect(json_response['data']['attributes']['regenerating']).to be(false)
    end
  end

  context 'when id is wrong' do
    let(:request) { get v1_chart_path('Wrong_ID'), headers: headers }

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
