# frozen_string_literal: true

RSpec.describe Question::Multiple, type: :model do
  describe 'Question::Multiple' do
    subject(:question_multiple) { build(:question_multiple) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_multiple) { create(:question_multiple) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_multiple.variable_clone_prefix([])[0]['variable']['name']).to eq('clone_answer_1')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_multiple.variable_clone_prefix(%w[clone_answer_1
                                                            clone1_answer_1])[0]['variable']['name']).to eq('clone2_answer_1')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_multiple.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_multiple.title).to include('from=>en to=>pl text=>Multiple')
        end

        it '#translate_subtitle' do
          question_multiple.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_multiple.subtitle).to equal(nil)
        end

        it '#translate_body' do
          question_multiple.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_multiple.body['data']).to include(
            {
              'payload' => '',
              'variable' => {
                'name' => 'answer_1',
                'value' => ''
              },
              'original_text' => ''
            },
            {
              'payload' => '',
              'variable' => {
                'name' => 'answer_2',
                'value' => ''
              },
              'original_text' => ''
            },
            {
              'payload' => '',
              'variable' => {
                'name' => 'answer_3',
                'value' => ''
              },
              'original_text' => ''
            },
            {
              'payload' => '',
              'variable' => {
                'name' => 'answer_4',
                'value' => ''
              },
              'original_text' => ''
            }
          )
        end
      end

      describe '#question_variables' do
        let(:expected) { (1..4).map { |i| "answer_#{i}" } }

        it 'returns correct variables' do
          expect(question_multiple.question_variables).to match_array expected
        end

        it 'returns correct amount of variables' do
          expect(question_multiple.question_variables.size).to eq expected.size
        end
      end
    end
  end
end
