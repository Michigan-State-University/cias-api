# frozen_string_literal: true

require 'rails_helper'

describe Api::EpicOnFhir::PatientVerification do
  subject { described_class.call(first_name, last_name, birth_date, phone_number, postal_code) }

  let(:first_name) { 'Camila' }
  let(:last_name) { 'Lopez' }
  let(:birth_date) { '1987-09-12' }
  let(:phone_number) { '469-555-5555' }
  let(:postal_code) { '75043' }

  it 'when API return correct data' do
    stub_request(:post, "#{ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')}?_format=json").
      to_return(status: 200, body: {
        resourceType: 'Bundle',
        type: 'searchset',
        total: 1,
        link: [
          {
            relation: 'self',
            url: 'https://fhir.epic.com/example'
          }
        ],
        entry: [
          {
            link: [
              {
                relation: 'self',
                url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Patient/erXuFYUfucBZaryVksYEcMg3'
              }
            ],
            fullUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Patient/erXuFYUfucBZaryVksYEcMg3',
            resource: {
              resourceType: 'Patient',
              id: 'erXuFYUfucBZaryVksYEcMg3',
              identifier: [
                {
                  use: 'usual',
                  type: {
                    text: 'EPIC'
                  },
                  system: 'urn:oid:1.2.840.114350.1.13.0.1.7.5.737384.0',
                  value: 'E4007'
                }
              ],
              active: true,
              managingOrganization: {
                reference: 'Organization/enRyWnSP963FYDpoks4NHOA3',
                display: 'Epic Hospital System'
              }
            },
            search: {
              extension: [
                {
                  valueCode: 'certain',
                  url: 'http://hl7.org/fhir/StructureDefinition/match-grade'
                }
              ],
              mode: 'match',
              score: 1
            }
          }
        ]
      }.to_json)

    expect(subject.class).to be(Hash)
  end

  it 'when third part tool return 404' do
    stub_request(:post, "#{ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')}?_format=json").
      to_return(status: 200, body: {
        resourceType: 'Bundle',
        type: 'searchset',
        total: 0,
        link: [
          {
            relation: 'self',
            url: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Patient/$match?_format=json'
          }
        ],
        entry: [
          {
            fullUrl: 'urn:uuid:00000000-0006-a576-746e-3f687d642f98',
            resource: {
              resourceType: 'OperationOutcome',
              issue: [
                {
                  severity: 'warning',
                  code: 'processing',
                  details: {
                    coding: [
                      {
                        system: 'urn:oid:1.2.840.114350.1.13.0.1.7.2.657369',
                        code: '4101',
                        display: 'Resource request returns no results.'
                      }
                    ],
                    text: 'Resource request returns no results.'
                  }
                }
              ]
            },
            search: {
              mode: 'outcome'
            }
          }
        ]
      }.to_json)

    expect { subject }.to raise_error(EpicOnFhir::NotFound)
  end
end
