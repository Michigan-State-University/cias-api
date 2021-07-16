# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/health_clinics/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) do
    create(:health_system, :with_health_system_admin, name: 'Health System 1', organization: organization)
  end
  let!(:health_clinic) { create(:health_clinic, name: 'Health Clinic', health_system: health_system) }
  let!(:deleted_health_clinic) { create(:health_clinic, name: 'Deleted Health Clinic', health_system: health_system, deleted_at: Time.current) }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      health_clinic: {
        name: 'New name'
      }
    }
  end
  let(:request) { patch v1_health_clinic_path(health_clinic.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_health_clinic_path(health_system.id) }

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
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => 'New name',
              'deleted' => false
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] } }
          }
        )
      end

      context 'when clinic is deleted' do
        let(:request) { patch v1_health_clinic_path(deleted_health_clinic.id), headers: headers }

        it 'return correct status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'return error message' do
          expect(json_response['message']).to include('Couldn\'t find HealthClinic with')
        end

        context 'with flag' do
          let(:params) do
            {
              with_deleted: true,
              health_clinic: {
                name: 'New name'
              }
            }
          end
          let(:request) { patch v1_health_clinic_path(deleted_health_clinic.id), headers: headers, params: params }

          it 'return sth' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    context 'when user is admin' do
      context 'when params are proper' do
        it_behaves_like 'permitted user'
      end

      context 'when params are invalid' do
        let(:params) do
          {
            health_system: {
              name: ''
            }
          }

          it { expect(response).to have_http_status(:unprocessable_entity) }

          it 'response contains proper error message' do
            expect(json_response['message']).to eq "Validation failed: Name can't be blank"
          end
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

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
