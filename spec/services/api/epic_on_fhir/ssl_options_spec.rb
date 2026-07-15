# frozen_string_literal: true

require 'rails_helper'

describe Api::EpicOnFhir::SslOptions do
  subject { described_class.call }

  # Minimal 3-level PKI mirroring HFH's real chain: root -> intermediate -> leaf.
  # Lets us assert that pinning the intermediate (partial chain) and anchoring on
  # the root both verify the same leaf, without depending on the system store.
  def build_cert(common_name, issuer: nil, issuer_key: nil, is_ca: false)
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = rand(1..1_000_000)
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}")
    cert.issuer = issuer ? issuer.subject : cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.zone.now - 1
    cert.not_after = Time.zone.now + 3600

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = issuer || cert
    cert.add_extension(ef.create_extension('basicConstraints', is_ca ? 'CA:TRUE' : 'CA:FALSE', true))

    cert.sign(issuer_key || key, OpenSSL::Digest.new('SHA256'))
    [cert, key]
  end

  let(:pki) do
    root, root_key = build_cert('Test Root', is_ca: true)
    intermediate, intermediate_key = build_cert('Test Intermediate', issuer: root, issuer_key: root_key, is_ca: true)
    leaf, = build_cert('leaf.example.org', issuer: intermediate, issuer_key: intermediate_key)
    { root: root, intermediate: intermediate, leaf: leaf }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_INTERMEDIATE_CERT', nil).and_return(pki[:intermediate].to_pem)
    allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_ROOT_CERT', nil).and_return(pki[:root].to_pem)
  end

  context 'by default (EPIC_ON_FHIR_CA_PIN_INTERMEDIATE unset)' do
    before { allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_PIN_INTERMEDIATE', true).and_return(true) }

    it 'keeps verification on' do
      expect(subject[:verify]).to be(true)
    end

    it 'pins the intermediate as a trust anchor (partial chain) and verifies the leaf' do
      store = subject[:cert_store]
      expect(store.verify(pki[:leaf], [pki[:intermediate]])).to be(true)
    end
  end

  context 'when EPIC_ON_FHIR_CA_PIN_INTERMEDIATE is false' do
    before { allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_PIN_INTERMEDIATE', true).and_return('false') }

    it 'anchors on the root and verifies the full chain' do
      store = subject[:cert_store]
      expect(store.verify(pki[:leaf], [pki[:intermediate]])).to be(true)
    end

    it 'rejects a leaf whose chain does not reach the trusted root' do
      other_root, other_key = build_cert('Rogue Root', is_ca: true)
      rogue_leaf, = build_cert('rogue.example.org', issuer: other_root, issuer_key: other_key)
      store = subject[:cert_store]
      expect(store.verify(rogue_leaf)).to be(false)
    end
  end

  context 'when the selected CA cert is a single line with escaped newlines' do
    before { allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_PIN_INTERMEDIATE', true).and_return(true) }

    it 'still builds a working trust store' do
      allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_INTERMEDIATE_CERT', nil)
                                   .and_return(pki[:intermediate].to_pem.gsub("\n", '\n'))
      store = subject[:cert_store]
      expect(store.verify(pki[:leaf], [pki[:intermediate]])).to be(true)
    end
  end

  context 'when the selected CA cert is not set' do
    before do
      allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_PIN_INTERMEDIATE', true).and_return(true)
      allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_CA_INTERMEDIATE_CERT', nil).and_return(nil)
    end

    it 'verifies against the system trust store only' do
      expect(subject).to eq(verify: true)
    end
  end
end
