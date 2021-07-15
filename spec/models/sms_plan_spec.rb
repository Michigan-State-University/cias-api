# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsPlan, type: :model do
  it { should belong_to(:session) }
  it { should have_many(:variants) }

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

  context 'translation' do
    let(:source_language_name_short) { 'en' }
    let(:destination_language_name_short) { 'pl' }
    let(:translation_service) { V1::Google::TranslationService.new }
    let(:variable_exclusive_translation_service) { V1::Translations::VariableExclusiveTranslationService.new(translation_service) }
    let(:sms_plan) { create(:sms_plan, no_formula_text: 'There is nothing to see here') }

    it '#translate_no_formula_text' do
      sms_plan.translate_no_formula_text(variable_exclusive_translation_service, source_language_name_short, destination_language_name_short)
      expect(sms_plan.no_formula_text).to eq('from=>en to=>pl text=>There is nothing to see here')
    end
  end
end
