# frozen_string_literal: true

require 'rails_helper'

describe Api::EpicOnFhir::SslOptions do
  subject { described_class.call }

  # A syntactically valid self-signed cert, standing in for HFH's intermediate.
  let(:ca_cert) do
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=Test CA')
    cert.not_before = Time.zone.now - 1
    cert.not_after = Time.zone.now + 3600
    cert.public_key = key.public_key
    cert.serial = 1
    cert.version = 2
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    cert.to_pem
  end

  context 'when EPIC_ON_FHIR_CA_CERT is not set' do
    before { allow(ENV).to receive(:[]).and_call_original }

    it 'verifies against the system trust store only' do
      allow(ENV).to receive(:[]).with('EPIC_ON_FHIR_CA_CERT').and_return(nil)

      expect(subject).to eq(verify: true)
    end
  end

  context 'when EPIC_ON_FHIR_CA_CERT is set' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('EPIC_ON_FHIR_CA_CERT').and_return(ca_cert)
    end

    it 'keeps verification on' do
      expect(subject[:verify]).to be(true)
    end

    it 'builds a trust store containing the supplied CA' do
      expect(subject[:cert_store]).to be_a(OpenSSL::X509::Store)
    end
  end

  context 'when EPIC_ON_FHIR_CA_CERT is a single line with escaped newlines' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('EPIC_ON_FHIR_CA_CERT').and_return(ca_cert.gsub("\n", '\n'))
    end

    it 'still builds a trust store' do
      expect(subject[:cert_store]).to be_a(OpenSSL::X509::Store)
    end
  end
end
