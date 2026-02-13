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

  context 'text splitting for ReadQuestion blocks' do
    let(:service) { described_class.new(question, translator, source_language_name_short, destination_language_name_short) }
    let(:question) { create(:question_single, :read_question_block, subtitle: subtitle) }
    let(:translator) { V1::Google::TranslationService.new }
    let(:source_language_name_short) { 'en' }
    let(:destination_language_name_short) { 'es' }

    context 'with English text' do
      let(:subtitle) { '<p>How are you feeling today?</p>' }

      it 'splits text correctly without creating punctuation-only elements' do
        result = service.send(:clear_and_split_text)
        
        expect(result).to be_an(Array)
        expect(result).not_to be_empty
        
        result.each do |part|
          stripped = part.tr('¿¡,!.?', '').strip
          expect(stripped).not_to be_empty, "Found punctuation-only element: #{part.inspect}"
        end
      end
    end

    context 'with Spanish inverted question mark at start' do
      let(:subtitle) { '<p>¿Cuántos años tiene?</p>' }

      it 'should NOT create a standalone ¿ element' do
        result = service.send(:clear_and_split_text)
        
        expect(result).to be_an(Array)
        
        punctuation_only = result.select { |part| part.tr('¿¡,!.?', '').strip.empty? }
        expect(punctuation_only).to be_empty, 
          "Found punctuation-only elements: #{punctuation_only.inspect}. Full result: #{result.inspect}"
      end

      it 'should keep inverted punctuation with the question text' do
        result = service.send(:clear_and_split_text)
        
        expect(result.join).to include('¿')
        
        expect(result).not_to include('¿')
      end
    end

    context 'with Spanish inverted exclamation mark' do
      let(:subtitle) { '<p>¡Bienvenido a la encuesta!</p>' }

      it 'should NOT create a standalone ¡ element' do
        result = service.send(:clear_and_split_text)
        
        punctuation_only = result.select { |part| part.tr('¿¡,!.?', '').strip.empty? }
        expect(punctuation_only).to be_empty,
          "Found punctuation-only elements: #{punctuation_only.inspect}. Full result: #{result.inspect}"
      end
    end

    context 'with multiple sentences in Spanish' do
      let(:subtitle) { '<p>¿Cómo está? Gracias por participar. ¡Bienvenido!</p>' }

      it 'should split sentences but not create punctuation-only elements' do
        result = service.send(:clear_and_split_text)
        
        expect(result).to be_an(Array)
        expect(result.length).to be > 1
        
        punctuation_only = result.select { |part| part.tr('¿¡,!.?', '').strip.empty? }
        expect(punctuation_only).to be_empty,
          "Found punctuation-only elements: #{punctuation_only.inspect}. Full result: #{result.inspect}"
      end
    end

    context 'integration: audio generation after text splitting' do
      let(:subtitle) { '<p>¿Cuántos años tiene?</p>' }
      let(:destination_language_name_short) { 'es' }

      before do
        allow(V1::AudioService).to receive(:call).and_return(
          instance_double('Audio', sha256: 'test_hash', url: '/test/audio.mp3')
        )
      end

      it 'should not generate nil audio URLs after translation' do
        described_class.call(question, translator, source_language_name_short, destination_language_name_short)
        
        question.reload
        narrator_blocks = question.narrator['blocks']
        
        narrator_blocks.each_with_index do |block, block_idx|
          next unless block['audio_urls']
          
          expect(block['audio_urls']).not_to include(nil),
            "Block #{block_idx} (type: #{block['type']}) has nil audio URLs. Text: #{block['text'].inspect}, Audio URLs: #{block['audio_urls'].inspect}"
          
          block['audio_urls'].each do |url|
            expect(url).not_to be_nil
            expect(url).to be_a(String)
          end
        end
      end

      it 'audio URLs count should match text elements count' do
        described_class.call(question, translator, source_language_name_short, destination_language_name_short)
        
        question.reload
        narrator_blocks = question.narrator['blocks']
        
        narrator_blocks.each do |block|
          next unless block['text'] && block['audio_urls']
          
          expect(block['audio_urls'].length).to eq(block['text'].length),
            "Mismatch: #{block['text'].length} texts but #{block['audio_urls'].length} audio URLs. Text: #{block['text'].inspect}"
        end
      end
    end
  end
end
