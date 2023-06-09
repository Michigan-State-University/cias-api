# frozen_string_literal: true

RSpec.describe V1::Translations::VariableExclusiveTranslationService do
  context 'translate text with variable names' do
    let(:translation_client) { V1::Google::TranslationService.new }
    let(:variable_exclusive_translation_service) { described_class.new(translation_client) }
    let(:source_language_name_short) { 'en' }
    let(:destination_language_name_short) { 'pl' }
    let(:input_with_variable_names) { 'Hello .:name:. How are you? Do you like your .:fruit:.' }

    it 'ignore variable names during translation' do
      output = variable_exclusive_translation_service.translate(input_with_variable_names, source_language_name_short, destination_language_name_short)
      expect(output).to eq("from=>#{source_language_name_short} to=>#{destination_language_name_short} text=>#{input_with_variable_names}")
    end

    it 'return blank text if given blank input' do
      output = variable_exclusive_translation_service.translate('', source_language_name_short, destination_language_name_short)
      expect(output).to eq('')
    end
  end
end
