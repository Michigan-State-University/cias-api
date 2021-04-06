# frozen_string_literal: true

RSpec.describe Question::Currency, type: :model do
  describe 'Question::Currency' do
    describe 'expected behaviour' do
      subject(:question_currency) { build(:question_currency) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'instance methods' do
        let(:question_currency) { create(:question_currency) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_currency.variable_clone_prefix([])).to eq('clone_currency_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_currency.variable_clone_prefix(%w[clone_currency_var clone1_currency_var])).to eq('clone2_currency_var')
          end
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_single, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end
end
