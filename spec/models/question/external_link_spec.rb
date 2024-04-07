# frozen_string_literal: true

RSpec.describe Question::ExternalLink, type: :model do
  describe 'Question::ExternalLink' do
    subject(:question_external_link) { build(:question_external_link) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_name, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

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

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_external_link.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_external_link.title).to include('from=>en to=>pl text=>External Link')
        end

        it '#translate_subtitle' do
          question_external_link.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_external_link.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns correct variables' do
          expect(question_external_link.question_variables).to match_array ['external_link_var']
        end

        it 'returns correct amount of variables' do
          expect(question_external_link.question_variables.size).to eq 1
        end
      end
    end
  end
end
