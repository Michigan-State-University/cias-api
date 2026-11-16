# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

describe Api::EpicOnFhir::PatientSearch do
  subject { described_class.call(patient_id) }

  let(:patient_id) { 'Z394' }
  let(:endpoint) { ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT').chomp('/') }
  let(:identifier_system) { 'urn:oid:1.2.3' }
  let(:identifier) { "#{identifier_system}|#{patient_id}" }
  let(:bundle) do
    { resourceType: 'Bundle', type: 'searchset', total: 1, entry: [{ resource: { resourceType: 'Patient' } }] }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM', nil).and_return(identifier_system)
    allow(Api::EpicOnFhir::Authentication).to receive(:call).and_return({ token_type: 'Bearer', access_token: 'token' })
  end

  it 'searches the endpoint qualified with the barcode identifier system' do
    stub = stub_request(:get, endpoint)
           .with(query: { '_format' => 'json', 'identifier' => identifier })
           .to_return(status: 200, body: bundle.to_json)

    subject

    expect(stub).to have_been_requested
  end

  it 'returns the parsed bundle' do
    stub_request(:get, endpoint)
      .with(query: { '_format' => 'json', 'identifier' => identifier })
      .to_return(status: 200, body: bundle.to_json)

    expect(subject[:total]).to eq(1)
  end

  context 'when the barcode identifier system is not configured' do
    let(:identifier_system) { nil }

    it 'fails closed without calling Epic' do
      expect { subject }.to raise_error(EpicOnFhir::UnexpectedError)
      expect(a_request(:get, /#{Regexp.escape(endpoint)}/)).not_to have_been_made
      expect(Api::EpicOnFhir::Authentication).not_to have_received(:call)
    end
  end

  it 'raises when no patient matches' do
    stub_request(:get, endpoint)
      .with(query: { '_format' => 'json', 'identifier' => identifier })
      .to_return(status: 200, body: bundle.merge(total: 0, entry: []).to_json)

    expect { subject }.to raise_error(EpicOnFhir::NotFound)
  end

  it 'raises on an unexpected status' do
    stub_request(:get, endpoint)
      .with(query: { '_format' => 'json', 'identifier' => identifier })
      .to_return(status: 400, body: '')

    expect { subject }.to raise_error(EpicOnFhir::UnexpectedError)
  end
end
