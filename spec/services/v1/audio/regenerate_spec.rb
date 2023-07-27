# frozen_string_literal: true

RSpec.describe V1::Audio::Regenerate do
  subject { described_class.new(regenerate_params, language_code, voice_type) }

  let(:question) do
    create(:question_single, narrator: { blocks: blocks, settings: { voice: true, character: 'peedy', animation: true, extra_space_for_narrator: false } })
  end
  let(:regenerate_params) { { question_id: question.id, block_index: 0, audio_index: 0, reflection_index: nil } }
  let(:language_code) { GoogleTtsLanguage.first }
  let(:voice_type) { GoogleTtsVoice.first }
  let(:audio) { create(:audio) }
  let(:text_to_speech) { instance_double(Audio::TextToSpeech) }
  let(:blocks) do
    [{
      audio_urls: ['test_audio'],
      type: 'speech',
      sha256: ['test'],
      text: ['test']
    }]
  end

  before do
    allow(Question).to receive(:find).with(question.id).and_return(question)
    allow(Audio).to receive(:find_by).and_return(audio)
    allow(Audio::TextToSpeech).to receive(:new).and_return(text_to_speech)
    allow(text_to_speech).to receive(:execute).and_return('test_url')
    allow(audio).to receive(:save!)
  end

  describe '.call' do
    it "calls the 'new' and 'call' methods with correct arguments" do
      expect(described_class).to receive(:new).with(regenerate_params, language_code, voice_type).and_call_original
      expect_any_instance_of(described_class).to receive(:call)

      described_class.call(regenerate_params, language_code, voice_type)
    end
  end

  describe '#initialize' do
    it 'assigns the correct instance variables' do
      expect(subject.question).to eq(question)
      expect(subject.block_index).to eq(regenerate_params[:block_index])
      expect(subject.block).to eq(question.narrator['blocks'][subject.block_index])
      expect(subject.audio_index).to eq(regenerate_params[:audio_index])
      expect(subject.reflection_index).to eq(regenerate_params[:reflection_index])
      expect(subject.language_code).to eq(language_code)
      expect(subject.voice_type).to eq(voice_type)
    end
  end

  describe '#call' do
    context 'when audio URL matches block audio URL' do
      before do
        allow(audio).to receive(:url).and_return(question.narrator['blocks'][0]['audio_urls'][0])
      end

      it 'calls the TextToSpeech service and updates the question' do
        expect(text_to_speech).to receive(:execute)
        expect(audio).to receive(:save!)
        expect(question).to receive(:save!)

        subject.call
      end
    end

    context 'when audio URL does not match block audio URL' do
      before do
        allow(audio).to receive(:url).and_return('https://example.com/other_audio.mp3')
      end

      it 'does not call the TextToSpeech service and does not update the question' do
        expect(Audio::TextToSpeech).not_to receive(:new)
        expect(text_to_speech).not_to receive(:execute)
        expect(audio).not_to receive(:save!)

        subject.call
      end
    end
  end

  context 'reflection' do
    let!(:blocks) do
      [{ type: 'Reflection', reflections: [{
        audio_urls: ['test_audio'],
        sha256: ['test'],
        text: ['test']
      }, {
        audio_urls: ['test_audio_2'],
        sha256: ['test_2'],
        text: ['test_2']

      }] }]
    end

    describe '#correct_block' do
      it 'returns the correct block and changes audio url based on the reflection index' do
        subject.instance_variable_set(:@reflection_index, 1)

        expect(subject.correct_block['audio_urls'][0]).not_to eq(blocks[0][:reflections][1][:text])
      end
    end
  end

  context 'speech' do
    it 'returns the block and change url if reflection index is nil' do
      expect(subject.correct_block['audio_urls'][0]).not_to eq(blocks[0][:audio_urls][0])
    end
  end
end
