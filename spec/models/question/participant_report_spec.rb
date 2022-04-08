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

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_participant_report.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_participant_report.title).to include('from=>en to=>pl text=>ParticipantReport')
        end

        it '#translate_subtitle' do
          question_participant_report.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_participant_report.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        let(:question_participant_report) { create(:question_participant_report, body: { variable: { name: 'htd' }, data: [{ payload: '' }] }) }

        it 'returns correct variables' do
          expect(question_participant_report.question_variables).to match_array ['htd']
        end

        it 'returns correct amount of variables' do
          expect(question_participant_report.question_variables.size).to eq 1
        end
      end
    end
  end
end
