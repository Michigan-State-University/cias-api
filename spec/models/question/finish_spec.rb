# frozen_string_literal: true

RSpec.describe Question::Finish, type: :model do
  describe 'Question::Finish' do
    subject(:question_finish) { build(:question_finish) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_finish) { create(:question_finish) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_finish.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_finish.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq(nil)
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_finish.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_finish.title).to include('from => en to => pl text => Enter title here')
        end

        it '#translate_subtitle' do
          question_finish.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_finish.subtitle).to include('from => en to => pl text => <h2>Enter main text for screen here </h2><br><i>Note: this is the last screen participants will see in this session</i>')
        end
      end
    end
  end
end
