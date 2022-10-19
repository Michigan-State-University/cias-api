# frozen_string_literal: true

RSpec.describe Question::Tlfb::TlfbEvents, type: :model do
  describe 'Question::Tlfb::TlfbEvents' do
    subject(:question_tlfb_event) { build(:question_tlfb_event) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_tlfb_event) { create(:question_tlfb_event) }

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_body' do
          question_tlfb_event.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_tlfb_event.body['data'][0])
            .to include(
              { 'payload' => { 'screen_title' => 'from=>en to=>pl text=>Hello', 'screen_question' => 'from=>en to=>pl text=>Did you drink alcohol today?' },
                'original_text' => { 'screen_title' => 'Hello', 'screen_question' => 'Did you drink alcohol today?' } }
            )
        end
      end
    end
  end
end
