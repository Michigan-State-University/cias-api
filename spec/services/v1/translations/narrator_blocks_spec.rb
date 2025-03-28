# frozen_string_literal: true

RSpec.describe V1::Translations::NarratorBlocks do
  subject { described_class.call(q_narrator_blocks_types, translator, source_language_name_short, destination_language_name_short) }

  let!(:q_narrator_blocks_types) { create(:question_single, :narrator_blocks_types_with_name_variable) }
  let(:translator) { V1::Google::TranslationService.new }
  let(:source_language_name_short) { 'en' }
  let(:destination_language_name_short) { 'pl' }

  before do
    subject
  end

  context 'translate narrator blocks with variable' do
    it 'changed text to speech' do
      expect(q_narrator_blocks_types.reload.narrator['blocks'].first).to include(
        'text' => include(
          'from=>en to=>pl text=>Medicine is the science and practice of establishing the diagnosis, prognosis, treatment, and prevention of disease.',
          'from=>en to=>pl text=>Working together as an interdisciplinary team, many highly trained health professionals',
          '.:name:.'
        )
      )
    end
  end

  context 'with narrator block with formula and cases' do
    let!(:q_narrator_blocks_types) { create(:question_single, :narrator_blocks_with_cases) }

    it 'changed text to speech' do
      expect(q_narrator_blocks_types.reload.narrator['blocks'].last['reflections'].first['text'])
        .to contain_exactly('from=>en to=>pl text=>Working together as an interdisciplinary team, many highly trained health professionals')
    end
  end

  context 'translate ReadQuestion block base on subtitle in question instead of defined blocks' do
    let!(:q_narrator_blocks_types) { create(:question_single, :read_question_block, subtitle: 'Example subtitle') }

    it 'changed text to speech' do
      expect(q_narrator_blocks_types.reload.narrator['blocks'].first).to include(
        'text' => include('Example subtitle')
      )
    end
  end
end
