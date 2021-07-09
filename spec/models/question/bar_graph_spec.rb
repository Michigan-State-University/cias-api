# frozen_string_literal: true

RSpec.describe Question::BarGraph, type: :model do
  describe 'Question::BarGraph' do
    subject(:question_bar_graph) { build(:question_bar_graph) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_bar_graph) { create(:question_bar_graph) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_bar_graph.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_bar_graph.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq(nil)
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_bar_graph.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_bar_graph.title).to include(
            {
              'from' => source_language_name_short,
              'to' => destination_language_name_short,
              'text' => 'Bar Graph'
            }.to_s
          )
        end

        it '#translate_subtitle' do
          question_bar_graph.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_bar_graph.subtitle).to equal(nil)
        end
      end
    end
  end
end
