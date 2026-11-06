# frozen_string_literal: true

require 'rails_helper'

describe Api::EpicOnFhir::SslOptions do
  subject { described_class.call }

  before { allow(ENV).to receive(:fetch).and_call_original }

  context 'by default (EPIC_ON_FHIR_SSL_VERIFY unset)' do
    before { allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_SSL_VERIFY', true).and_return(true) }

    it 'verifies against the system trust store' do
      expect(subject).to eq(verify: true)
    end
  end

  context 'when EPIC_ON_FHIR_SSL_VERIFY is "true"' do
    before { allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_SSL_VERIFY', true).and_return('true') }

    it 'keeps verification on' do
      expect(subject).to eq(verify: true)
    end
  end

  context 'when EPIC_ON_FHIR_SSL_VERIFY is "false"' do
    before { allow(ENV).to receive(:fetch).with('EPIC_ON_FHIR_SSL_VERIFY', true).and_return('false') }

    it 'disables verification (break-glass rollback)' do
      expect(subject).to eq(verify: false)
    end
  end
end
