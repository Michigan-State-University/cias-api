# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsPlan::Variant, type: :model do
  it { should belong_to(:sms_plan) }

  describe 'translation' do
    let(:translation_client) { V1::Google::TranslationService.new }
    let(:translation_service) { V1::Translations::VariableExclusiveTranslationService.new(translation_client) }
    let(:source_language_short_name) { 'en' }
    let(:dest_language_short_name) { 'pl' }
    let(:test_sms_plan_variants) do
      [
        create(:sms_plan_variant, content: 'This is first SMS message'),
        create(:sms_plan_variant, content: 'And this is second'),
        create(:sms_plan_variant, content: 'And here be dragons'),
        create(:sms_plan_variant, content: 'Hello .:name:. How are you? Do you like your .:fruit:.'),
        create(:sms_plan_variant, content: 'I am .:name:. from .:city:..'),
        create(:sms_plan_variant, content: 'I am .:age:. years old.')
      ]
    end
    let(:variant_with_blank_content) { create(:sms_plan_variant, content: '         ') }
    let(:results) { [] }

    it 'properly translate sms message without variables' do
      test_sms_plan_variants.each do |variant|
        variant.translate_content(translation_service, source_language_short_name, dest_language_short_name)
        results << variant.content.include?({
          'from' => source_language_short_name,
          'to' => dest_language_short_name,
          'text' => variant.original_text['content']
        }.to_s)
      end
      expect(results).to all(be_truthy)
    end

    it 'return blank text when given blank input' do
      variant_with_blank_content.translate_content(translation_service, source_language_short_name, dest_language_short_name)

      expect(variant_with_blank_content.content).to eq('         ')
    end
  end
end
