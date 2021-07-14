# frozen_string_literal: true

RSpec.describe Question::FollowUpContact, type: :model do
  describe 'Question::FollowUpContact' do
    subject(:question_follow_up_contact) { build(:question_follow_up_contact) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_follow_up_contact) { create(:question_follow_up_contact) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_follow_up_contact.variable_clone_prefix([])).to eq('clone_follow_up_contact_var')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_follow_up_contact.variable_clone_prefix(%w[clone_follow_up_contact_var clone1_follow_up_contact_var])).to eq('clone2_follow_up_contact_var')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_follow_up_contact.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_follow_up_contact.title).to include('from => en to => pl text => Follow-up contact')
        end

        it '#translate_subtitle' do
          question_follow_up_contact.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_follow_up_contact.subtitle).to equal(nil)
        end
      end
    end
  end
end
