# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/henry_ford/new_patient', type: :request do
  let(:params) do
    {
      patientID: '89008709',
      lastName: 'Flintstone',
      firstName: 'Fred',
      dob: '19780809',
      gender: 'M',
      zip: ' 49201-1753',
      visitID: 'H93905_1010010049_10727228307'
    }
  end
  let(:oauth_application) { create(:oauth_application) }
  let(:headers) { { Accept: 'application/json' } }
  let(:access_token) do
    create(:oauth_access_token, application: oauth_application)
  end
  let(:request_headers) { { Authorization: "Bearer #{access_token.plaintext_token}" } }

  let(:request) { post v1_henry_ford_new_patient_path, params: params, headers: request_headers }

  before { request }

  it {
    expect(response).to have_http_status(:ok)
  }

  context 'when data are invalid' do
    let(:params) do
      {
        patientID: '89008709',
        lastName: 'Flintstone'
      }
    end

    it {
      expect(response).to have_http_status(:unprocessable_entity)
    }
  end
end
