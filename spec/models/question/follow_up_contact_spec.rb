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
          expect(question_follow_up_contact.variable_clone_prefix(%w[clone_follow_up_contact_var
                                                                     clone1_follow_up_contact_var])).to eq('clone2_follow_up_contact_var')
        end
      end
    end
  end
end
