# frozen_string_literal: true

RSpec.describe Question::Feedback, type: :model do
  describe 'Question::Feedback' do
    subject(:question_feedback) { build(:question_feedback) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_name, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_feedback) { create(:question_feedback) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_feedback.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_feedback.variable_clone_prefix(%w[clone_question_slider_var
                                                            clone1_question_slider_var])).to eq(nil)
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_feedback.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_feedback.title).to include('from=>en to=>pl text=>Feedback')
        end

        it '#translate_subtitle' do
          question_feedback.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_feedback.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns empty variables list' do
          expect(question_feedback.question_variables).to match_array []
        end
      end
    end
  end
end
