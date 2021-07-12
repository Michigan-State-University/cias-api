# frozen_string_literal: true

RSpec.describe Question::Grid, type: :model do
  describe 'Question::Grid' do
    subject(:question_grid) { build(:question_grid) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_grid) { create(:question_grid) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_grid.variable_clone_prefix([])[0]['variable']['name']).to eq('clone_row1')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_grid.variable_clone_prefix(%w[clone_row1 clone1_row1])[0]['variable']['name']).to eq('clone2_row1')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_grid.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_grid.title).to include(
            {
              'from' => source_language_name_short,
              'to' => destination_language_name_short,
              'text' => 'Grid'
            }.to_s
          )
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
    end
  end
end
