# frozen_string_literal: true

RSpec.describe Question::Date, type: :model do
  describe 'Question::Date' do
    describe 'expected behaviour' do
      subject(:question_date) { build(:question_date) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'instance methods' do
        let(:question_date) { create(:question_date) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_date.variable_clone_prefix([])).to eq('clone_date_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_date.variable_clone_prefix(%w[clone_date_var clone1_date_var])).to eq('clone2_date_var')
          end
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_date, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end
end
