# frozen_string_literal: true

RSpec.describe Question::ParticipantReport, type: :model do
  describe 'Question::ParticipantReport' do
    subject(:question_participant_report) { build(:question_participant_report) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_participant_report) { create(:question_participant_report) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_participant_report.variable_clone_prefix([])).to eq(nil)
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_participant_report.variable_clone_prefix(%w[clone_free_response_var
                                                                      clone1_free_response_var])).to eq(nil)
        end
      end
    end
  end
end
