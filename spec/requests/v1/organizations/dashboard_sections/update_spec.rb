# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/organizations/:organization_id/dashboard_sections/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, :with_dashboard_section) }
  let!(:dashboard_section) { organization.reporting_dashboard.dashboard_sections.first }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      dashboard_section: {
        name: 'New name',
        description: 'New description'
      }
    }
  end
  let(:request) do
    patch v1_organization_dashboard_section_path(organization.id, dashboard_section.id), params: params,
                                                                                         headers: headers
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_organization_dashboard_section_path(organization.id, dashboard_section.id) }

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
            'id' => dashboard_section.id,
            'type' => 'dashboard_section',
            'attributes' => {
              'name' => 'New name',
              'description' => 'New description',
              'reporting_dashboard_id' => organization.reporting_dashboard.id,
              'organization_id' => organization.id,
              'position' => 1
            }
          }
        )
      end
    end

    context 'when user is admin' do
      context 'when params are proper' do
        it_behaves_like 'permitted user'
      end

      context 'when name in params is empty' do
        before { request }

        let(:params) do
          {
            dashboard_section: {
              name: ''
            }
          }
        end

        it 'returns correct status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns proper data' do
          expect(json_response['data']).to include(
            {
              'id' => dashboard_section.id,
              'type' => 'dashboard_section',
              'attributes' => {
                'name' => dashboard_section.name,
                'description' => dashboard_section.description,
                'reporting_dashboard_id' => organization.reporting_dashboard.id,
                'organization_id' => organization.id,
                'position' => 1
              }
            }
          )
        end
      end

      context 'when params are invalid' do
        before do
          organization.reporting_dashboard.dashboard_sections.create(name: 'Another Dashboard Section')
          request
        end

        let(:params) do
          {
            dashboard_section: {
              name: 'Another Dashboard Section'
            }
          }
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq 'Validation failed: Name has already been taken'
        end
      end
    end

    context 'when user is e_intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

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

    %i[organization_admin health_system_admin health_clinic_admin team_admin researcher participant
       guest].each do |role|
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
