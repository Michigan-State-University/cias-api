# frozen_string_literal: true

RSpec.describe Question::FreeResponse, type: :model do
  describe 'Question::FreeResponse' do
    describe 'expected behaviour' do
      subject(:question_free_response) { build(:question_free_response) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'validation of question assignments' do
        let(:question) { build(:question_free_response, question_group: question_group) }

        it_behaves_like 'cannot be assigned to sms session'
        it_behaves_like 'can be assigned to classic session'
      end

      describe 'instance methods' do
        let(:question_free_response) { create(:question_free_response) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_free_response.variable_clone_prefix([])).to eq('clone_free_response_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_free_response.variable_clone_prefix(%w[clone_free_response_var
                                                                   clone1_free_response_var])).to eq('clone2_free_response_var')
          end
        end

        describe 'translation' do
          let(:translator) { V1::Google::TranslationService.new }
          let(:source_language_name_short) { 'en' }
          let(:destination_language_name_short) { 'pl' }

          it '#translate_title' do
            question_free_response.translate_title(translator, source_language_name_short, destination_language_name_short)
            expect(question_free_response.title).to include('from=>en to=>pl text=>Free Response')
          end

          it '#translate_subtitle' do
            question_free_response.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
            expect(question_free_response.subtitle).to equal(nil)
          end
        end

        describe '#question_variables' do
          it 'returns correct variables' do
            expect(question_free_response.question_variables).to contain_exactly('free_response_var')
          end

          it 'returns correct amount of variables' do
            expect(question_free_response.question_variables.size).to eq 1
          end
        end
      end
    end

    describe '#text_limit' do
      let(:question_free_response) { create(:question_free_response) }

      it 'contains text_limit variable' do
        expect(question_free_response.settings['text_limit']).to eq(250)
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_free_response, :body_data_empty) }

      it { expect(with_empty.save).to be false }
    end
  end
end
