# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::EpicOnFhir::PatientVerification do
  include WebMock::API
  WebMock.enable!

  subject { described_class.call(first_name, last_name, birth_date, phone_number, phone_tye, postal_code) }

  let(:first_name) { 'Camila' }
  let(:last_name) { 'Lopez' }
  let(:birth_date) { '1987-09-12' }
  let(:phone_number) { '469-555-5555' }
  let(:phone_tye) { 'home' }
  let(:postal_code) { '75043' }

  it 'when API return correct data' do
    stub_request(:post, "#{ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')}$match?_format=json").
      to_return(status: 200, body: File.read('spec/fixtures/integrations/henry_ford/patient_resource.json'))

    expect(subject.class).to be(Hash)
  end

  it 'when third part tool return 404' do
    stub_request(:post, "#{ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')}$match?_format=json").
      to_return(status: 200, body: File.read('spec/fixtures/integrations/henry_ford/patient_not_found.json'))

    expect { subject }.to raise_error(EpicOnFhir::NotFound)
  end
end
