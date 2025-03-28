# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/health_clinics/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, :with_health_system_admin, name: 'Michigan Public Health System', organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:health_clinic_admin) { health_clinic.user_health_clinics.first.user }
  let!(:chart_statistic) { create(:chart_statistic, health_clinic: health_clinic) }

  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_health_clinic_path(health_clinic.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_health_clinic_path(health_clinic.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'return correct organizable and user_health_clinics' do
        expect(health_clinic_admin.reload.organizable_id).to be_nil
        expect(health_clinic_admin.user_health_clinics).to be_empty
      end

      it 'returns correct status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'health clinic is deleted' do
        expect(HealthClinic.find_by(id: health_system.id)).to be_nil
      end

      it 'health_clinic admin active status is false' do
        expect(health_clinic_admin.reload.active?).to be(false)
      end

      it 'does not change chart statistic count' do
        expect { request }.to avoid_changing(ChartStatistic, :count)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when health system id is invalid' do
        before do
          delete v1_health_clinic_path('wrong_id'), headers: headers
        end

        it 'error message is expected' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when user is e-intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'permitted user'

      context 'when the clinic has a short link' do
        let!(:short_link) { create(:short_link, linkable: create(:intervention), health_clinic: health_clinic) }

        it 'delete assigned short_link' do
          expect { request }.to change(ShortLink, :count).by(-1)
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

    %i[health_system_admin organization_admin team_admin researcher participant guest].each do |role|
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
