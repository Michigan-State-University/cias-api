# frozen_string_literal: true

RSpec.describe V1::Translation do
  context 'test parameters' do
    it 'return correct data' do
      expect(described_class.call('Hello world!', 'en', 'la')).to eq('Salve mundi!')
    end

    it 'without original language' do
      expect(described_class.call('Hello my friend.', '', 'la')).to eq('Salve amice.')
    end

    it 'without target language' do
      expect { described_class.call('Hello my friend.', '', '') }.to raise_error(Google::Cloud::InvalidArgumentError)
    end

    it 'ignore wrong original language' do
      expect(described_class.call('Hello my friend.', 'pl', 'la')).to eq('Salve amice.')
    end
  end
end
