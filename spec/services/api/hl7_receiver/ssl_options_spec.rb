# frozen_string_literal: true

require 'rails_helper'

describe Api::Hl7Receiver::SslOptions do
  subject { described_class.call }

  # Minimal 3-level PKI mirroring HF's real chain: root -> intermediate -> leaf.
  # Lets us assert the added root/intermediate verify the leaf without pinning and
  # without depending on the system store.
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

  def self.ssl_settings(verify:, ca_cert:)
    { 'HL7_RECEIVER_SSL_VERIFY' => verify, 'HL7_RECEIVER_CA_CERT' => ca_cert }
  end

  # The PEMs come from the per-example PKI (a `let`), so the CA cert settings are written in a `before`;
  # the environment-variables context still restores it, because its keys include HL7_RECEIVER_CA_CERT.

  %w[false 0 off].each do |verify|
    context "when HL7_RECEIVER_SSL_VERIFY is #{verify.inspect} (the rollback)" do
      include_context 'with environment variables', ssl_settings(verify: verify, ca_cert: nil)

      it 'returns verify:false with no cert_store' do
        expect(subject).to eq(verify: false)
      end
    end
  end

  [nil, ''].each do |verify|
    context "when HL7_RECEIVER_SSL_VERIFY is #{verify.inspect}" do
      include_context 'with environment variables', ssl_settings(verify: verify, ca_cert: '')

      it 'still verifies' do
        expect(subject).to eq(verify: true)
      end
    end
  end

  context 'when HL7_RECEIVER_SSL_VERIFY is on' do
    context 'and HL7_RECEIVER_CA_CERT is blank' do
      include_context 'with environment variables', ssl_settings(verify: 'true', ca_cert: '')

      it 'verifies against the system trust store only' do
        expect(subject).to eq(verify: true)
      end
    end

    context 'and HL7_RECEIVER_CA_CERT carries the root + intermediate' do
      include_context 'with environment variables', ssl_settings(verify: 'true', ca_cert: nil)

      before { ENV['HL7_RECEIVER_CA_CERT'] = [pki[:root].to_pem, pki[:intermediate].to_pem].join }

      it 'keeps verification on and adds a cert_store' do
        expect(subject[:verify]).to be(true)
        expect(subject[:cert_store]).to be_a(OpenSSL::X509::Store)
      end

      it 'verifies a leaf that chains to the added root (no pinning)' do
        store = subject[:cert_store]
        expect(store.verify(pki[:leaf], [pki[:intermediate]])).to be(true)
      end

      it 'rejects a leaf that does not chain to the added root' do
        rogue_root, rogue_key = build_cert('Rogue Root', is_ca: true)
        rogue_leaf, = build_cert('rogue.example.org', issuer: rogue_root, issuer_key: rogue_key)
        store = subject[:cert_store]
        expect(store.verify(rogue_leaf)).to be(false)
      end
    end

    context 'and HL7_RECEIVER_CA_CERT is a single line with escaped newlines' do
      include_context 'with environment variables', ssl_settings(verify: 'true', ca_cert: nil)

      before { ENV['HL7_RECEIVER_CA_CERT'] = [pki[:root].to_pem, pki[:intermediate].to_pem].join.gsub("\n", '\n') }

      it 'still builds a working trust store' do
        store = subject[:cert_store]
        expect(store.verify(pki[:leaf], [pki[:intermediate]])).to be(true)
      end
    end
  end
end
