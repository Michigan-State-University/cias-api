# frozen_string_literal: true

RSpec.describe Question::Phone, type: :model do
  describe 'Question::Phone' do
    subject(:question_phone) { build(:question_phone) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_phone, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

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

      describe '#question_variables' do
        let(:question_phone) { create(:question_phone, body: { variable: { name: 'htd' }, data: [{ payload: '' }] }) }

        it 'returns correct amount of variables' do
          expect(question_phone.question_variables.size).to eq 1
        end

        it 'returns correct variable names' do
          expect(question_phone.question_variables).to match_array ['htd']
        end
      end
    end
  end
end
