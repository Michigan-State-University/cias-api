# frozen_string_literal: true

RSpec.describe V1::Translations::NarratorBlocks do
  context 'translate narrator blocks with variable' do
    subject { described_class.call(q_narrator_blocks_types, translator, source_language_name_short, destination_language_name_short) }

    let!(:q_narrator_blocks_types) { create(:question_single, :narrator_blocks_types_with_name_variable) }
    let(:translator) { V1::Google::TranslationService.new }
    let(:source_language_name_short) { 'en' }
    let(:destination_language_name_short) { 'pl' }

    before do
      subject
    end

    it 'changed text to speech' do
      expect(q_narrator_blocks_types.reload.narrator['blocks'].first).to include(
        { 'text' => include(
          {
            'to' => 'pl',
            'from' => 'en',
            'text' => 'Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.'
          },
          {
            'to' => 'pl',
            'from' => 'en',
            'text' => 'Working together as an interdisciplinary team, many highly trained health professionals'
          },
          '.:name:.'
        ) }
      )
    end
  end
end
