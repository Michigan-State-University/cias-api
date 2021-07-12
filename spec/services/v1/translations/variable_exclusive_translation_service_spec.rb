# frozen_string_literal: true

RSpec.describe V1::Translations::VariableExclusiveTranslationService do
  context 'translate text with variable names' do
    let(:translation_client) { V1::Google::TranslationService.new }
    let(:variable_exclusive_translation_service) { V1::Translations::VariableExclusiveTranslationService.new(translation_client) }
    let(:source_language_name_short) { 'en' }
    let(:destination_language_name_short) { 'pl' }
    let(:input_with_variable_names) { 'Hello .:name:. How are you? Do you like your .:fruit:.' }

    it 'ignore variable names during translation' do

    end

  end
end
