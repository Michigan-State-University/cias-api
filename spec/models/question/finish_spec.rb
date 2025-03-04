# frozen_string_literal: true

RSpec.describe Question::Finish, type: :model do
  describe 'Question::Finish' do
    subject(:question_finish) { create(:question_finish) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_finish, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_finish) { create(:question_finish) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_finish.variable_clone_prefix([])).to be_nil
        end

        it 'returns nil with passed taken variables' do
          expect(question_finish.variable_clone_prefix(%w[clone_question_slider_var
                                                          clone1_question_slider_var])).to be_nil
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_finish.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_finish.title).to include('from=>en to=>pl text=><h2>Enter title here</h2>')
        end

        it '#translate_subtitle' do
          question_finish.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_finish.subtitle).to include('from=>en to=>pl text=><p>Enter main text for screen here</p><p><br></p><p><em>Note: this is the last screen participants will see in this session</em></p>') # rubocop:disable Layout/LineLength
        end
      end

      describe '#question_variables' do
        it 'returns empty variables list' do
          expect(question_finish.question_variables).to be_empty
        end
      end
    end
  end
end
