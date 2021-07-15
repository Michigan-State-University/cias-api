# frozen_string_literal: true

RSpec.describe Question::Feedback, type: :model do
  describe 'Question::Feedback' do
    subject(:question_feedback) { build(:question_feedback) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_feedback) { create(:question_feedback) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_feedback.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_feedback.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq(nil)
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
    end
  end
end
