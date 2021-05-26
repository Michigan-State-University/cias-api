# frozen_string_literal: true

RSpec.describe Question::ExternalLink, type: :model do
  describe 'Question::ExternalLink' do
    subject(:question_external_link) { build(:question_external_link) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_external_link) { create(:question_external_link) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_external_link.variable_clone_prefix([])).to eq('clone_external_link_var')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_external_link.variable_clone_prefix(%w[clone_external_link_var
                                                                 clone1_external_link_var])).to eq('clone2_external_link_var')
        end
      end
    end
  end
end
