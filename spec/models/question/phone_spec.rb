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

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_phone.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_phone.title).to include('from=>en to=>pl text=>Phone')
        end

        it '#translate_subtitle' do
          question_phone.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_phone.subtitle).to equal(nil)
        end
      end
    end
  end
end
