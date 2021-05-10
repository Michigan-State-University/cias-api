# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/charts/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:chart) { create(:chart, name: 'Chart', description: 'Some description', organization_id: organization.id) }
  let!(:e_intervention_admin) { organization.organization_admins.first }

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
              'organization_id' => organization.id,
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
  end

end
