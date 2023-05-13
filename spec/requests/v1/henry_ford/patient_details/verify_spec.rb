# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/henry_ford/verify', type: :request do
  let(:user) { create(:user, :confirmed, :participant) }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      hfhs_patient_data: {
        first_name: 'example',
        last_name: 'example',
        dob: 'example',
        sex: 'example',
        zip_code: 'example'
      }
    }
  end
  let(:request) { post v1_henry_ford_verify_path, params: params, headers: headers }

  before { request }
  # TODO
#   context 'when auth' do
#     context 'is invalid' do
#       let(:request) { post v1_health_systems_path }
#
#       it_behaves_like 'unauthorized user'
#     end
#
#     context 'is valid' do
#       it_behaves_like 'authorized user'
#     end
#   end
#
#   context 'when user is registered participant' do
#     it 'returns correct status' do
#       expect(response).to have_http_status(:ok)
#     end
#
#     it 'return correct result' do
#       expect(json_response['data']['id']).to eq(hfhs_data.id)
#     end
#
#     it 'correctly assigned data to user' do
#       expect(user.reload.hfhs_patient_detail).to eq(hfhs_data)
#     end
#
#     context 'when mrn is provided ignore rest of params' do
#       let(:params) do
#         {
#           hfhs_patient_data: {
#             first_name: 'FakeFirstName',
#             mrn: hfhs_data.patient_id
#           }
#         }
#       end
#
#       it 'returns correct status' do
#         expect(response).to have_http_status(:ok)
#       end
#
#       it 'correctly assigned data to user' do
#         expect(user.reload.hfhs_patient_detail).to eq(hfhs_data)
#       end
#     end
#   end
#
#   context 'when user is quest' do
#     let(:user) { create(:user, :confirmed, :guest) }
#
#     it 'returns correct status' do
#       expect(response).to have_http_status(:ok)
#     end
#
#     it 'patient data doesn\'t assign ' do
#       expect(user.reload.hfhs_patient_detail).to eq(hfhs_data)
#     end
#   end
#
#   context 'when params are incorrect' do
#     let(:params) do
#       {
#         hfhs_patient_data: {
#           first_name: 'FakeFirstName',
#           last_name: 'FakeLastName',
#           dob: hfhs_data.dob,
#           sex: hfhs_data.sex,
#           zip_code: hfhs_data.zip_code
#         }
#       }
#     end
#
#     it 'return correct status' do
#       expect(response).to have_http_status(:not_found)
#     end
#   end
# end
