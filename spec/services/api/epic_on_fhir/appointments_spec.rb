# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::EpicOnFhir::Appointments do
  subject { described_class.call(patient_id) }

  let(:patient_id) { 'example_patient_id' }

  it 'when API return correct data' do
    stub_request(:post, ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT').to_s)
      .with(query: { '_format' => 'json', 'patient' => patient_id })
      .to_return(status: 200, body: File.read('spec/fixtures/integrations/henry_ford/appointments.json'))

    expect(subject.class).to be(Hash)
  end

  it 'when third party tool return empty collection' do
    stub_request(:post, ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT').to_s)
      .with(query: { '_format' => 'json', 'patient' => patient_id })
      .to_return(status: 200, body: {
        resourceType: 'Bundle',
        type: 'searchset',
        total: 0,
        link: [
          {
            relation: 'self',
            url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Appointment?_format=json&patient=erXuFYUfucBZaryVksYEcMg3&identifier=1505'
          }
        ],
        entry: []
      }.to_json)

    expect { subject }.to raise_error(EpicOnFhir::NotFound)
  end

  it 'when third party tool return unexpected status' do
    stub_request(:post, ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT').to_s)
      .with(query: { '_format' => 'json', 'patient' => patient_id })
      .to_return(status: 400, body: '')

    expect { subject }.to raise_error(EpicOnFhir::UnexpectedError)
  end
end
