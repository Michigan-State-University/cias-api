# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::EpicOnFhir::PatientSearch do
  subject { described_class.call(patient_id) }

  let(:patient_id) { 'Z394' }
  let(:endpoint) { ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT').chomp('/') }
  let(:bundle) do
    { resourceType: 'Bundle', type: 'searchset', total: 1, entry: [{ resource: { resourceType: 'Patient' } }] }
  end

  it 'searches the endpoint without its trailing slash' do
    stub = stub_request(:get, endpoint)
           .with(query: { '_format' => 'json', 'identifier' => patient_id })
           .to_return(status: 200, body: bundle.to_json)

    subject

    expect(stub).to have_been_requested
  end

  it 'returns the parsed bundle' do
    stub_request(:get, endpoint)
      .with(query: { '_format' => 'json', 'identifier' => patient_id })
      .to_return(status: 200, body: bundle.to_json)

    expect(subject[:total]).to eq(1)
  end

  context 'when the barcode identifier system is configured' do
    before { allow(ENV).to receive(:fetch).and_call_original }

    it 'qualifies the identifier with it' do
      allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM', nil).and_return('urn:oid:1.2.3')

      stub = stub_request(:get, endpoint)
             .with(query: { '_format' => 'json', 'identifier' => "urn:oid:1.2.3|#{patient_id}" })
             .to_return(status: 200, body: bundle.to_json)

      subject

      expect(stub).to have_been_requested
    end
  end

  it 'raises when no patient matches' do
    stub_request(:get, endpoint)
      .with(query: { '_format' => 'json', 'identifier' => patient_id })
      .to_return(status: 200, body: bundle.merge(total: 0, entry: []).to_json)

    expect { subject }.to raise_error(EpicOnFhir::NotFound)
  end

  it 'raises on an unexpected status' do
    stub_request(:get, endpoint)
      .with(query: { '_format' => 'json', 'identifier' => patient_id })
      .to_return(status: 400, body: '')

    expect { subject }.to raise_error(EpicOnFhir::UnexpectedError)
  end
end
