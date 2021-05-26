# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/charts', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      chart: {
        name: 'New Chart',
        description: 'Description',
        dashboard_section_id: dashboard_section.id,
        chart_type: 'bar_chart'
      }
    }
  end
  let(:request) { post v1_charts_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_charts_path }

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
        expect(response).to have_http_status(:created)
      end

      it 'returns proper data' do
        expect(json_response['data']['attributes']).to include(
          {
            'dashboard_section_id' => dashboard_section.id,
            'name' => 'New Chart',
            'description' => 'Description'
          }
        )
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when params are invalid' do
        let(:params) do
          {
            chart: {
              name: nil
            }
          }

          it { expect(response).to have_http_status(:unprocessable_entity) }

          it 'response contains proper error message' do
            expect(json_response['message']).to eq "Validation failed: Name can't be blank"
          end
        end
      end
    end

    context 'when user is e_intervention admin' do
      let(:user) { create(:user, :confirmed, :e_intervention_admin) }

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
