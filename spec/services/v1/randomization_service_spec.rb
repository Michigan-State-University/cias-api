# frozen_string_literal: true

RSpec.describe V1::RandomizationService do
  subject { described_class.new(target_array) }

  describe 'target array have a some records' do
    let(:target_array) do
      [
        { 'id' => 'question_1', 'probability' => '50', type: 'Question::Single' },
        { 'id' => 'question_2', 'probability' => '20', type: 'Question::Single' },
        { 'id' => 'question_2', 'probability' => '30', type: 'Question::Single' }
      ]
    end

    it 'return question approximately correct time' do
      target_array.each do |target|
        counter = 0
        1_000_000.times { counter += 1 if subject.call == target }
        counter /= 10_000
        expect(counter).to be >= (target['probability'].to_i - 1)
        expect(counter).to be <= (target['probability'].to_i + 1)
      end
    end
  end

  describe 'target array have an one records without probability' do
    let(:target_array) do
      [
        { 'id' => 'question_1', type: 'Question::Single' }
      ]
    end

    it 'return first question' do
      expect(subject.call).to eq(target_array[0])
    end
  end
end
