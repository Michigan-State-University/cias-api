# frozen_string_literal: true

RSpec.describe Question::HenryFord, type: :model do
  describe 'Question::HenryFord' do
    describe 'expected behaviour' do
      subject(:question_henry_ford) { build(:question_henry_ford) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'validation of question assignments' do
        let(:question) { build(:question_henry_ford, question_group: question_group) }

        it_behaves_like 'cannot be assigned to sms session'
        it_behaves_like 'can be assigned to classic session'
      end

      describe 'instance methods' do
        let(:question_henry_ford) { create(:question_henry_ford) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_henry_ford.variable_clone_prefix([])).to eq('clone_AUDIT_1')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_henry_ford.variable_clone_prefix(%w[clone_AUDIT_1
                                                                clone1_AUDIT_1])).to eq('clone2_AUDIT_1')
          end
        end

        describe '#question_variables' do
          it 'returns correct amount of variables' do
            expect(question_henry_ford.question_variables.size).to eq 1
          end

          it 'returns correct variable names' do
            expect(question_henry_ford.question_variables).to contain_exactly('AUDIT_1')
          end
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_henry_ford.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_henry_ford.title).to include('from=>en to=>pl text=>HenryFord')
        end

        it '#translate_subtitle' do
          question_henry_ford.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_henry_ford.subtitle).to equal(nil)
        end

        it '#translate_body' do
          question_henry_ford.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_henry_ford.body['data']).to include(
            { 'hfh_value' => 'hfh1',
              'original_text' => 'Never',
              'payload' => 'from=>en to=>pl text=>Never',
              'value' => 'Never' },
            { 'hfh_value' => 'hfh2',
              'original_text' => 'Monthly or less',
              'payload' => 'from=>en to=>pl text=>Monthly or less',
              'value' => 'Monthly or less' }
          )
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_single, :body_data_empty) }

      it { expect(with_empty.save).to be false }
    end
  end
end
