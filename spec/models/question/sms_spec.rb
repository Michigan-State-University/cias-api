# frozen_string_literal: true

RSpec.describe Question::Sms, type: :model do
  describe 'Question::Sms' do
    subject(:question_sms) { build(:question_sms) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_sms, question_group: question_group) }
      it_behaves_like 'can be be assigned to sms session'
      it_behaves_like 'cannot be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_sms) { create(:question_sms) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_sms.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_sms.variable_clone_prefix(%w[clone_question_slider_var
                                                        clone1_question_slider_var])).to eq(nil)
        end
      end

      describe '#question_variables' do
        it 'returns correct variables' do
          expect(question_sms.question_variables).to match_array ['.:name:.']
        end

        it 'returns correct amount of variables' do
          expect(question_sms.question_variables.size).to eq 1
        end
      end
    end
  end
end
