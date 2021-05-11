# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/charts/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:chart) { create(:chart, name: 'Chart', description: 'Some description', dashboard_section_id: dashboard_section.id) }
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
              'formula' => {
                'payload' => '',
                'patterns' => []
              },
              'dashboard_section_id' => dashboard_section.id,
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
