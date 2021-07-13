# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsPlan::Variant, type: :model do
  it { should belong_to(:sms_plan) }

  describe 'translation' do
    let(:translation_client) { V1::Google::TranslationService.new }
    let(:variable_exclusive_translation_service) { V1::Translations::VariableExclusiveTranslationService.new(translation_client) }
    let(:source_language_short_name) { 'en' }
    let(:dest_language_short_name) { 'pl' }
    let(:test_sms_plan_variants) do
      [
      ]
    end
  end
end
