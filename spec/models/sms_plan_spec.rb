# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsPlan, type: :model do
  it { should belong_to(:session) }

  context 'validations' do
    context 'when are params are valid' do
      let!(:sms_plan) { build_stubbed(:sms_plan) }

      it 'is valid' do
        expect(sms_plan).to be_valid
      end
    end

    context 'when the name is empty' do
      let!(:sms_plan) { build_stubbed(:sms_plan, name: nil) }

      it 'is not valid' do
        expect(sms_plan).not_to be_valid
      end
    end

    context 'when the schedule is empty' do
      let!(:sms_plan) { build_stubbed(:sms_plan, schedule: nil) }

      it 'is not valid' do
        expect(sms_plan).not_to be_valid
      end
    end

    context 'when the frequency is empty' do
      let!(:sms_plan) { build_stubbed(:sms_plan, frequency: nil) }

      it 'is not valid' do
        expect(sms_plan).not_to be_valid
      end
    end

    context 'when the session is empty' do
      let!(:sms_plan) { build_stubbed(:sms_plan, session: nil) }

      it 'is not valid' do
        expect(sms_plan).not_to be_valid
      end
    end
  end
end
