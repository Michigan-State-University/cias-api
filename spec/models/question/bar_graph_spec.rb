# frozen_string_literal: true

RSpec.describe Question::BarGraph, type: :model do
  describe 'Question::BarGraph' do
    subject(:question_bar_graph) { build(:question_bar_graph) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_bar_graph, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_bar_graph) { create(:question_bar_graph) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_bar_graph.variable_clone_prefix([])).to be_nil
        end

        it 'returns nil with passed taken variables' do
          expect(question_bar_graph.variable_clone_prefix(%w[clone_question_slider_var
                                                             clone1_question_slider_var])).to be_nil
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_bar_graph.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_bar_graph.title).to include('from=>en to=>pl text=>Bar Graph')
        end

        it '#translate_subtitle' do
          question_bar_graph.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_bar_graph.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        let(:question_bar_graph) { create(:question_bar_graph, body: { variable: { name: 'htd' }, data: [{ payload: '', value: '' }] }) }

        it 'returns correct variables' do
          expect(question_bar_graph.question_variables).to contain_exactly('htd')
        end

        it 'returns correct amount of variables' do
          expect(question_bar_graph.question_variables.size).to eq 1
        end
      end
    end
  end
end
