# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsCode, type: :model do
  subject { create(:sms_code) }

  it { should belong_to(:session) }
  it { should belong_to(:health_clinic).optional(true) }

  describe 'validations' do
    context 'when sms_code is active' do
      subject { build(:sms_code, active: true) }

      it { should validate_presence_of(:sms_code) }
      it { should validate_uniqueness_of(:sms_code) }
      it { should validate_length_of(:sms_code).is_at_least(SmsCode::SMS_CODE_MIN_LENGTH) }
    end

    context 'when sms_code is inactive' do
      subject { build(:sms_code, active: false) }

      it 'does not validate presence of sms_code' do
        subject.sms_code = nil
        expect(subject).to be_valid
      end

      it 'does not validate uniqueness of sms_code' do
        create(:sms_code, sms_code: 'DUPLICATE', active: false)
        subject.sms_code = 'DUPLICATE'
        expect(subject).to be_valid
      end
    end
  end

  describe '#status_cannot_be_start_or_stop' do
    context 'when sms_code is active' do
      let(:sms_code) { build(:sms_code, active: true) }

      context 'when sms_code is STOP (case insensitive)' do
        it 'is invalid with uppercase STOP' do
          sms_code.sms_code = 'STOP'
          expect(sms_code).not_to be_valid
          expect(sms_code.errors[:sms_code]).to be_present
        end

        it 'is invalid with lowercase stop' do
          sms_code.sms_code = 'stop'
          expect(sms_code).not_to be_valid
          expect(sms_code.errors[:sms_code]).to be_present
        end

        it 'is invalid with mixed case Stop' do
          sms_code.sms_code = 'Stop'
          expect(sms_code).not_to be_valid
          expect(sms_code.errors[:sms_code]).to be_present
        end
      end

      context 'when sms_code is START (case insensitive)' do
        it 'is invalid with uppercase START' do
          sms_code.sms_code = 'START'
          expect(sms_code).not_to be_valid
          expect(sms_code.errors[:sms_code]).to be_present
        end

        it 'is invalid with lowercase start' do
          sms_code.sms_code = 'start'
          expect(sms_code).not_to be_valid
          expect(sms_code.errors[:sms_code]).to be_present
        end

        it 'is invalid with mixed case Start' do
          sms_code.sms_code = 'Start'
          expect(sms_code).not_to be_valid
          expect(sms_code.errors[:sms_code]).to be_present
        end
      end

      context 'when sms_code is valid' do
        it 'is valid with allowed code' do
          sms_code.sms_code = 'VALID_CODE'
          expect(sms_code).to be_valid
        end

        it 'is valid with code containing stop/start as substring' do
          sms_code.sms_code = 'STOPPED'
          expect(sms_code).to be_valid
          sms_code.sms_code = 'STARTING'
          expect(sms_code).to be_valid
        end
      end
    end

    context 'when sms_code is inactive' do
      let(:sms_code) { build(:sms_code, active: false) }

      it 'allows STOP when inactive' do
        sms_code.sms_code = 'STOP'
        expect(sms_code).to be_valid
      end

      it 'allows START when inactive' do
        sms_code.sms_code = 'START'
        expect(sms_code).to be_valid
      end
    end
  end
end
