# frozen_string_literal: true

RSpec.describe V1::AudioService do
  context 'text unification' do
    it 'correctly unifies text' do
      expect(described_class.new('Example').text).to eq('example')
      expect(described_class.new('.Example').text).to eq('example')
      expect(described_class.new('Example         ,!').text).to eq('example')
      expect(described_class.new('   Example.').text).to eq('example')
    end
  end

  context 'execution' do
    let(:audio) { described_class.call(text, preview: preview) }
    let(:text) { 'Example' }
    let(:preview) { false }

    context 'when there are no audios matching text' do
      context 'when audio is not for preview' do
        it 'correctly returns new audio when no audio is present' do
          expect(audio.usage_counter).to eq(1)
        end
      end

      context 'when audio is for preview' do
        let(:preview) { true }

        it 'correctly returns new audio when no audio is present' do
          expect(audio.usage_counter).to eq(0)
        end
      end
    end

    context 'when there is an audio matching text' do
      let!(:other_audio) do
        create(:audio, sha256: Digest::SHA256.hexdigest('example_en-US_en-US-Standard-C'), language: 'en-US',
                       voice_type: 'en-US-Standard-C', usage_counter: 5)
      end

      context 'when audio is not for preview' do
        it 'correctly returns new audio when no audio is present' do
          expect(audio.usage_counter).to eq(5)
        end
      end

      context 'when audio is for preview' do
        let(:preview) { true }

        it 'correctly returns new audio when no audio is present' do
          expect(audio.usage_counter).to eq(5)
        end
      end
    end
  end

  context 'concurrency safety (find-or-create race)' do
    let(:text) { 'Example' }

    it 'reuses the same Audio row on repeated calls (no duplicate, no error)' do
      first = described_class.call(text)
      expect { @second = described_class.call(text) }.not_to change(Audio, :count)
      expect(@second).to eq(first)
    end

    it 'recovers without raising when the row already exists on the create branch' do
      service = described_class.new(text)
      digest = service.prepare_audio_digest
      winner = create(:audio, sha256: digest, language: 'en-US', voice_type: 'en-US-Standard-C', usage_counter: 9)

      # Drive the create branch directly to simulate losing the find/create race to a
      # concurrent request that already inserted the row.
      result = nil
      expect { result = service.send(:create_audio, digest) }.not_to raise_error
      expect(result).to eq(winner)
      expect(Audio.where(sha256: digest).count).to eq(1)
    end
  end
end
