# frozen_string_literal: true

RSpec.describe Question::Grid, type: :model do
  describe 'Question::Grid' do
    subject(:question_grid) { build(:question_grid) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_grid, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_grid) { create(:question_grid) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_grid.variable_clone_prefix([])[0]['variable']['name']).to eq('clone_row1')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_grid.variable_clone_prefix(%w[clone_row1
                                                        clone1_row1])[0]['variable']['name']).to eq('clone2_row1')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_grid.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_grid.title).to include('from=>en to=>pl text=>Grid')
        end

        it '#translate_subtitle' do
          question_grid.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_grid.subtitle).to equal(nil)
        end

        it '#translate_body' do
          question_grid.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_grid.body['data']).to include(
            {
              'payload' => {
                'columns' => [
                  {
                    'original_text' => '',
                    'payload' => '',
                    'variable' => {
                      'value' => '1'
                    }
                  },
                  {
                    'original_text' => '',
                    'payload' => '',
                    'variable' => {
                      'value' => '1'
                    }
                  }
                ],
                'rows' => [
                  {
                    'original_text' => '',
                    'payload' => '',
                    'variable' => {
                      'name' => 'row1'
                    }
                  }
                ]
              }
            }
          )
        end
      end

      describe '#question_variables' do
        it 'returns correct variables' do
          expect(question_grid.question_variables).to contain_exactly('row1')
        end

        it 'returns correct amount of variables' do
          expect(question_grid.question_variables.size).to eq 1
        end
      end
    end
  end
end
