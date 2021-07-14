# frozen_string_literal: true

RSpec.describe Question::Number, type: :model do
  describe 'Question::Number' do
    subject(:question_number) { build(:question_number) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_number) { create(:question_number) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_number.variable_clone_prefix([])).to eq('clone_number_var')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_number.variable_clone_prefix(%w[clone_number_var clone1_number_var])).to eq('clone2_number_var')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_number.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_number.title).to include('from => en to => pl text => Number')
        end

        it '#translate_subtitle' do
          question_number.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_number.subtitle).to equal(nil)
        end
      end
    end
  end
end
