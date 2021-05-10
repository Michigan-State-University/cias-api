# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/charts', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:other_organization) { create(:organization, :with_e_intervention_admin, name: 'Other Organization') }
  let!(:chart) { create(:chart, name: 'Chart1', organization_id: organization.id) }
  let!(:other_chart) { create(:chart, name: 'Chart2', organization_id: organization.id) }
  let!(:chart_in_other_organization) { create(:chart, name: 'Chart3', organization_id: other_organization.id) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }

  let(:headers) { user.create_new_auth_token }

  let(:request) { get v1_charts_path(chart.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_charts_path(chart.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is admin' do
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
        },
        {
          'id' => other_chart.id.to_s,
          'type' => 'chart',
          'attributes' => {
            'name' => other_chart.name,
            'description' => other_chart.description,
            'status' => 'draft',
            'formula' => {
              'payload' => '',
              'patterns' => []
            },
            'organization_id' => organization.id,
            'published_at' => nil
          }
        },
        {
          'id' => chart_in_other_organization.id.to_s,
          'type' => 'chart',
          'attributes' => {
            'name' => chart_in_other_organization.name,
            'description' => chart_in_other_organization.description,
            'status' => 'draft',
            'formula' => {
              'payload' => '',
              'patterns' => []
            },
            'organization_id' => other_organization.id,
            'published_at' => nil
          }
        }
      )
    end

    it 'return correct size' do
      expect(json_response['data'].size).to eq(3)
    end
  end

  context 'when user is e-intervention admin' do
    let(:user) { e_intervention_admin }

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
        },
        {
          'id' => other_chart.id.to_s,
          'type' => 'chart',
          'attributes' => {
            'name' => other_chart.name,
            'description' => other_chart.description,
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

    it 'return correct size' do
      expect(json_response['data'].size).to eq(2)
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[health_system_admin team_admin researcher participant guest health_clinic_admin].each do |role|
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
