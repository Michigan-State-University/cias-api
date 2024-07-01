# frozen_string_literal: true

RSpec.describe Question::SmsInformation, type: :model do
  describe 'Question::SmsInformation' do
    subject(:question_sms_information) { build(:question_sms_information) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_sms_information, question_group: question_group) }

      it_behaves_like 'can be assigned to sms session'
      it_behaves_like 'cannot be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_sms_information) { create(:question_sms_information) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_sms_information.variable_clone_prefix([])).to be_nil
        end

        it 'returns nil with passed taken variables' do
          expect(question_sms_information.variable_clone_prefix(%w[clone_question_slider_var
                                                                   clone1_question_slider_var])).to be_nil
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_subtitle' do
          question_sms_information.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms_information.subtitle).to include('from=>en to=>pl text=>Name screen')
        end
      end

      describe '#question_variables' do
        it 'returns empty variables list' do
          expect(question_sms_information.question_variables).to match_array []
        end
      end
    end
  end
end
