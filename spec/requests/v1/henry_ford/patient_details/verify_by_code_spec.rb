# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/henry_ford/verify_by_code', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }
  let(:valid_barcode) { '<PtID>Z394</PtID><PtDAT>54348</PtDAT><UID> ' }
  let(:params) do
    {
      hfhs_patient_data: {
        barcode: valid_barcode
      }
    }
  end
  let(:epic_response) do
    {
      resourceType: 'Bundle',
      type: 'searchset',
      total: 1,
      entry: [
        {
          resource: {
            resourceType: 'Patient',
            id: 'test-patient-id',
            identifier: [
              {
                type: { text: 'OTHER_SYSTEM' },
                value: 'other-value'
              },
              {
                type: { text: ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER', 'KEY_TO_IDENTIFYING_SPECIFIC_SYSTEM') },
                value: '89010892'
              }
            ],
            name: [
              {
                given: ['John'],
                family: 'Doe'
              }
            ],
            birthDate: '1980-01-01',
            gender: 'male',
            address: [
              {
                use: 'home',
                postalCode: '12345'
              }
            ],
            telecom: [
              {
                use: 'mobile',
                value: '+1234567890'
              }
            ]
          }
        }
      ]
    }
  end
  let(:request) { post v1_henry_ford_verify_by_code_path, params: params, headers: headers }

  context 'when epic returns one patient' do
    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response)
    end

    context 'when auth' do
      before do
        request
      end

      context 'is invalid' do
        let(:request) { post v1_henry_ford_verify_by_code_path, params: params }

        it_behaves_like 'unauthorized user'
      end

      context 'is valid' do
        it_behaves_like 'authorized user'
      end
    end

    context 'when user is registered participant' do
      before do
        request
      end

      it 'returns correct status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns serialized HfhsPatientDetail' do
        json_response = response.parsed_body
        expect(json_response).to have_key('data')
        expect(json_response['data']).to have_key('id')
        expect(json_response['data']).to have_key('type')
        expect(json_response['data']['type']).to eq('hfhs_patient_detail')
      end

      it 'creates patient detail record with correct data' do
        json_response = response.parsed_body
        patient_detail = HfhsPatientDetail.find(json_response['data']['id'])

        expect(patient_detail.patient_id).to eq('89010892')
        expect(patient_detail.first_name).to eq('John')
        expect(patient_detail.last_name).to eq('Doe')
        expect(patient_detail.dob).to eq(Date.parse('1980-01-01'))
        expect(patient_detail.sex).to eq('male')
        expect(patient_detail.zip_code).to eq('12345')
        expect(patient_detail.phone_type).to eq('mobile')
        expect(patient_detail.phone_number).to eq('+1234567890')
        expect(patient_detail.pending).to be true
      end
    end

    context 'when user is guest' do
      let(:user) { create(:user, :confirmed, :guest) }

      before do
        request
      end

      it 'returns correct status' do
        expect(response).to have_http_status(:ok)
      end

      it 'creates patient detail record' do
        json_response = response.parsed_body
        expect(json_response['data']['type']).to eq('hfhs_patient_detail')
      end
    end

    context 'when barcode is invalid' do
      before do
        request
      end

      context 'when barcode is empty' do
        let(:params) do
          {
            hfhs_patient_data: {
              barcode: ''
            }
          }
        end

        it 'returns error status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when barcode is nil' do
        let(:params) do
          {
            hfhs_patient_data: {
              barcode: nil
            }
          }
        end

        it 'returns error status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when barcode format is invalid' do
        let(:params) do
          {
            hfhs_patient_data: {
              barcode: 'invalid_barcode_format'
            }
          }
        end

        it 'returns error status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when patient ID is missing from barcode' do
        let(:params) do
          {
            hfhs_patient_data: {
              barcode: '<PtDAT>54348</PtDAT><UID> '
            }
          }
        end

        it 'returns error status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when patient already exists in database' do
      let!(:existing_patient) do
        create(:hfhs_patient_detail,
               patient_id: '89010892',
               first_name: 'John',
               last_name: 'Doe',
               dob: Date.parse('1980-01-01'),
               sex: 'male',
               zip_code: '12345',
               phone_type: 'mobile',
               phone_number: '+1234567890',
               pending: false)
      end

      before do
        request
      end

      it 'returns correct status' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates existing record to pending true' do
        json_response = response.parsed_body
        patient_detail = HfhsPatientDetail.find(json_response['data']['id'])

        expect(patient_detail.id).to eq(existing_patient.id)
        expect(patient_detail.pending).to be true
      end

      it 'does not create new record' do
        expect(HfhsPatientDetail.count).to eq(1)
      end
    end

    context 'when required parameters are missing' do
      before do
        request
      end

      context 'when hfhs_patient_data is missing' do
        let(:params) { {} }

        it 'returns error status' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'when barcode parameter is missing' do
        let(:params) do
          {
            hfhs_patient_data: {}
          }
        end

        it 'returns error status' do
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end

  context 'when Epic API returns multiple patients' do
    let(:epic_response_multiple) do
      epic_response.merge(total: 2)
    end

    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_multiple)
      request
    end

    it 'returns error status' do
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'when Epic API returns no patients' do
    let(:epic_response_empty) do
      epic_response.merge(total: 0)
    end

    before do
      allow_any_instance_of(Api::EpicOnFhir::PatientSearch).to receive(:call).and_return(epic_response_empty)
      request
    end

    it 'returns error status' do
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
