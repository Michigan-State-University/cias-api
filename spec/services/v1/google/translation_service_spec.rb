# frozen_string_literal: true

RSpec.describe V1::Google::TranslationService do
  context 'test parameters' do
    it 'return correct data' do
      expect(described_class.new.translate(text = 'Hello world!', 'en', 'la')).to eq({
                                                                                       'text' => 'Hello world!',
                                                                                       'from' => 'en',
                                                                                       'to' => 'la'
                                                                                     })
    end

    it 'without target language' do
      expect { described_class.new.translate('Hello my friend.', 'en', nil) }.to raise_error(Google::Cloud::InvalidArgumentError)
    end
  end
end
