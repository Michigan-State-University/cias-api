# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/henry_ford/verify', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let!(:hfhs_data) { create(:hfhs_patient_detail) }
  let!(:session) do
    create(:session,
           intervention: create(:intervention,
                                intervention_locations: [create(:intervention_location,
                                                                clinic_location: create(:clinic_location, name: 'brukowa', department: 'HTD',
                                                                                                          external_name: 'brukowa'))]))
  end

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      hfhs_patient_data: {
        first_name: hfhs_data.first_name,
        last_name: hfhs_data.last_name,
        dob: hfhs_data.dob,
        sex: hfhs_data.sex,
        zip_code: hfhs_data.zip_code,
        phone_number: hfhs_data.phone_number,
        phone_type: hfhs_data.phone_type
      },
      session_id: session.id
    }
  end
  let(:request) { post v1_henry_ford_verify_path, params: params, headers: headers }

  before do
    allow_any_instance_of(Date).to receive(:future?).and_return(true)

    allow_any_instance_of(Api::EpicOnFhir::PatientVerification).to receive(:call).and_return(
      JSON.parse(File.read('spec/fixtures/integrations/henry_ford/patient_resource.json')).deep_symbolize_keys
    )
    allow_any_instance_of(Api::EpicOnFhir::Appointments).to receive(:call).and_return(
      JSON.parse(File.read('spec/fixtures/integrations/henry_ford/appointments.json')).deep_symbolize_keys
    )

    request
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_health_systems_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is registered participant' do
    it 'returns correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct result' do
      expect(json_response['data']['id']).to eq(hfhs_data.id)
    end

    it 'correctly assigned data to user' do
      expect(user.reload.hfhs_patient_detail).to eq(hfhs_data)
    end
  end

  context 'when user is quest' do
    let(:user) { create(:user, :confirmed, :guest) }

    it 'returns correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'patient data doesn\'t assign ' do
      expect(user.reload.hfhs_patient_detail).to eq(hfhs_data)
    end
  end
end
