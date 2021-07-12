# frozen_string_literal: true

RSpec.describe Question::Single, type: :model do
  describe 'Question::Single' do
    describe 'expected behaviour' do
      subject(:question_single) { build(:question_single) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'instance methods' do
        let(:question_single) { create(:question_single) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_single.variable_clone_prefix([])).to eq('clone_single_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_single.variable_clone_prefix(%w[clone_single_var clone1_single_var])).to eq('clone2_single_var')
          end
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_single.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_single.title).to include(
            {
              'from' => source_language_name_short,
              'to' => destination_language_name_short,
              'text' => 'Single'
            }.to_s
          )
        end

        it '#translate_subtitle' do
          question_single.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_single.subtitle).to equal(nil)
        end

        it '#translate_body' do
          question_single.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_single.body['data']).to include(
            {
              'payload' => '',
              'value' => '',
              'original_text' => ''
            },
            {
              'payload' => {
                'from' => 'en',
                'to' => 'pl',
                'text' => 'example2'
              },
              'value' => '',
              'original_text' => 'example2'
            }
          )
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_single, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end
end
