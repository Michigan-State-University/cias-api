# frozen_string_literal: true

RSpec.describe Question::Date, type: :model do
  describe 'Question::Date' do
    describe 'expected behaviour' do
      subject(:question_date) { build(:question_date) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'validation of question assignments' do
        let(:question) { build(:question_date, question_group: question_group) }

        it_behaves_like 'cannot be assigned to sms session'
        it_behaves_like 'can be assigned to classic session'
      end

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

        describe 'translation' do
          let(:translator) { V1::Google::TranslationService.new }
          let(:source_language_name_short) { 'en' }
          let(:destination_language_name_short) { 'pl' }

          it '#translate_title' do
            question_date.translate_title(translator, source_language_name_short, destination_language_name_short)
            expect(question_date.title).to include('from=>en to=>pl text=>date')
          end

          it '#translate_subtitle' do
            question_date.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
            expect(question_date.subtitle).to equal(nil)
          end
        end

        describe '#question_variables' do
          it 'returns correct variables' do
            expect(question_date.question_variables).to contain_exactly('date_var')
          end

          it 'returns correct amount of variables' do
            expect(question_date.question_variables.size).to eq 1
          end
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_date, :body_data_empty) }

      it { expect(with_empty.save).to be false }
    end
  end
end
