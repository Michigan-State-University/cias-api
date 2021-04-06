# frozen_string_literal: true

RSpec.describe Question::FreeResponse, type: :model do
  describe 'Question::FreeResponse' do
    describe 'expected behaviour' do
      subject(:question_free_response) { build(:question_free_response) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'instance methods' do
        let(:question_free_response) { create(:question_free_response) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_free_response.variable_clone_prefix([])).to eq('clone_free_response_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_free_response.variable_clone_prefix(%w[clone_free_response_var clone1_free_response_var])).to eq('clone2_free_response_var')
          end
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_free_response, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end
end
