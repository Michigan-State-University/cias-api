# frozen_string_literal: true

RSpec.describe Question::Tlfb::TlfbQuestion, type: :model do
  describe 'Question::Tlfb::TlfbQuestion' do
    subject(:question_tlfb) { build(:question_tlfb_question) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_tlfb) { create(:question_tlfb_question, :with_substances) }

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_body' do
          question_tlfb.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_tlfb.body['data'][0])
            .to include(
              { 'payload' =>
                 { 'question_title' => 'from=>en to=>pl text=>Questions',
                   'head_question' => 'from=>en to=>pl text=>Test question',
                   'substance_question' => 'from=>en to=>pl text=>Test substance question',
                   'substances_with_group' => false,
                   'substances' => [
                     { 'name' => 'from=>en to=>pl text=>Gin', 'variable' => 'gin', 'unit' => nil },
                     { 'name' => 'from=>en to=>pl text=>Wine', 'variable' => 'wine', 'unit' => nil }
                   ] },
                'original_text' =>
                 { 'question_title' => 'Questions',
                   'head_question' => 'Test question',
                   'substance_question' => 'Test substance question',
                   'substances_with_group' => false,
                   'substances' => [
                     { 'name' => 'Gin', 'variable' => 'gin' },
                     { 'name' => 'Wine', 'variable' => 'wine' }
                   ] } }
            )
        end

        describe 'with substances group' do
          let(:question_tlfb) { create(:question_tlfb_question, :with_substance_groups) }

          it '#translate_body' do
            question_tlfb.translate_body(translator, source_language_name_short, destination_language_name_short)
            expect(question_tlfb.body['data'][0])
              .to include(
                { 'payload' =>
                   { 'question_title' => 'from=>en to=>pl text=>Questions',
                     'head_question' => 'from=>en to=>pl text=>Test question',
                     'substance_question' => 'from=>en to=>pl text=>Test substance question',
                     'substances_with_group' => true,
                     'substance_groups' =>
                      [{ 'name' => 'from=>en to=>pl text=>Smokers group',
                         'substances' =>
                          [{ 'name' => 'from=>en to=>pl text=>cigarettes', 'unit' => 'from=>en to=>pl text=>cigs', 'variable' => 'cigarettes' },
                           { 'name' => 'from=>en to=>pl text=>cannabis', 'unit' => 'from=>en to=>pl text=>grams', 'variable' => 'cannabis' }] },
                       { 'name' => 'from=>en to=>pl text=>Alcohol group',
                         'substances' =>
                          [{ 'name' => 'from=>en to=>pl text=>Vodka', 'unit' => 'from=>en to=>pl text=>shots', 'variable' => 'vodka' },
                           { 'name' => 'from=>en to=>pl text=>Beer', 'unit' => 'from=>en to=>pl text=>cups', 'variable' => 'beer' }] }] },
                  'original_text' =>
                   { 'question_title' => 'Questions',
                     'head_question' => 'Test question',
                     'substance_question' => 'Test substance question',
                     'substances_with_group' => true,
                     'substance_groups' =>
                      [{ 'name' => 'Smokers group',
                         'substances' => [
                           { 'name' => 'cigarettes', 'unit' => 'cigs', 'variable' => 'cigarettes' },
                           { 'name' => 'cannabis', 'unit' => 'grams', 'variable' => 'cannabis' }
                         ] },
                       { 'name' => 'Alcohol group',
                         'substances' => [
                           { 'name' => 'Vodka', 'unit' => 'shots', 'variable' => 'vodka' },
                           { 'name' => 'Beer', 'unit' => 'cups', 'variable' => 'beer' }
                         ] }] } }
              )
          end
        end
      end
    end
  end
end
