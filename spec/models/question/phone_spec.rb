# frozen_string_literal: true

RSpec.describe Question::Phone, type: :model do
  describe 'Question::Phone' do
    subject(:question_phone) { build(:question_phone) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_phone) { create(:question_phone) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_phone.variable_clone_prefix([])).to eq(nil)
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_phone.variable_clone_prefix(%w[clone_free_response_var clone1_free_response_var])).to eq(nil)
        end
      end
    end
  end
end
