# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::ParticipantUploads::Scanner do
  describe '.build' do
    it 'builds the GuardDuty adapter by default' do
      expect(described_class.build).to be_a(V1::ParticipantUploads::GuardDutyS3Adapter)
    end

    it 'builds the local adapter when configured' do
      allow(Settings.participant_uploads).to receive(:scanner).and_return('accept_all')

      expect(described_class.build).to be_a(V1::ParticipantUploads::AcceptAllAdapter)
    end

    it 'refuses an unknown scanner instead of falling back' do
      allow(Settings.participant_uploads).to receive(:scanner).and_return('nonsense')

      expect { described_class.build }.to raise_error(described_class::UnknownScannerError)
    end

    it 'never lets production scan nothing' do
      allow(Settings.participant_uploads).to receive(:scanner).and_return('accept_all')
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect { described_class.build }.to raise_error(described_class::InsecureScannerError)
    end
  end
end
