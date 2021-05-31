# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/health_clinics', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:new_health_system_admin) { create(:user, :confirmed, :health_system_admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      health_clinic: {
        name: 'New Health Clinic',
        health_system_id: health_system.id
      }
    }
  end
  let(:request) { post v1_health_clinics_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_health_clinics_path }

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
        expect(json_response['data']).to include(
          {
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => 'New Health Clinic',
              'health_clinic_admins' => []
            }
          }
        )
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

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

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
