# frozen_string_literal: true

RSpec.describe Question::FollowUpContact, type: :model do
  describe 'Question::FollowUpContact' do
    subject(:question_follow_up_contact) { build(:question_follow_up_contact) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_name, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_follow_up_contact) { create(:question_follow_up_contact) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_follow_up_contact.variable_clone_prefix([])).to eq('clone_follow_up_contact_var')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_follow_up_contact.variable_clone_prefix(%w[clone_follow_up_contact_var
                                                                     clone1_follow_up_contact_var])).to eq('clone2_follow_up_contact_var')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_follow_up_contact.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_follow_up_contact.title).to include('from=>en to=>pl text=>Follow-up contact')
        end

        it '#translate_subtitle' do
          question_follow_up_contact.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_follow_up_contact.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns correct variables' do
          expect(question_follow_up_contact.question_variables).to match_array ['follow_up_contact_var']
        end

        it 'returns correct amount of variables' do
          expect(question_follow_up_contact.question_variables.size).to eq 1
        end
      end
    end
  end
end
