# frozen_string_literal: true

RSpec.describe Question::Sms, type: :model do
  describe 'Question::Sms' do
    describe 'expected behaviour' do
      subject(:question_sms) { build(:question_sms) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'validation of question assignments' do
        let(:question) { build(:question_sms, question_group: question_group) }

        it_behaves_like 'can be assigned to sms session'
        it_behaves_like 'cannot be assigned to classic session'
      end

      describe 'instance methods' do
        let(:question_sms) { create(:question_sms) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_sms.variable_clone_prefix([])).to eq('clone_sms_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_sms.variable_clone_prefix(%w[clone_sms_var
                                                         clone1_sms_var])).to eq('clone2_sms_var')
          end
        end

        describe '#question_variables' do
          it 'returns correct amount of variables' do
            expect(question_sms.question_variables.size).to eq 1
          end

          it 'returns correct variable names' do
            expect(question_sms.question_variables).to match_array ['sms_var']
          end
        end

        describe '#schedule_at' do
          context 'when weekly period is provided' do
            let(:question_sms) { create(:question_sms,
                                        sms_schedule: { "period": 'weekly',
                                                        "day_of_period": 'monday',
                                                        "time": { exact: '8:00 AM' } })}
            it 'returns proper date' do
              date = Date.current.wday === 1 ?
                       DateTime.current.change({hour: 8}) :
                       DateTime.commercial(Date.today.year, 1+Date.today.cweek, 1).change({hour: 8})
              expect(question_sms.schedule_at).to eq date
            end
          end

          context 'when monthly period is provided' do
            let(:question_sms) { create(:question_sms,
                                        sms_schedule: { "period": 'monthly',
                                                        "day_of_period": '1',
                                                        "time": { exact: '8:00 AM' } })}
            it 'returns proper date' do
              date = Date.current.mday === 1 ?
                       DateTime.current.change({hour: 8}) :
                       DateTime.current.change({month: DateTime.current.month + 1, day: 1, hour: 8})
              expect(question_sms.schedule_at).to eq date
            end
          end

          context 'when daily period is provided' do
            let(:question_sms) { create(:question_sms,
                                        sms_schedule: { "period": 'daily',
                                                        "day_of_period": '1',
                                                        "time": { exact: '8:00 AM' } })}
            it 'returns proper date' do
              date = DateTime.current.hour >= 8 && DateTime.current.minute >= 0 && DateTime.current.second >= 0 ?
                       DateTime.current.change({day: DateTime.current.day + 1, hour: 8}) :
                       DateTime.current.change({hour: 8})
              expect(question_sms.schedule_at).to eq date
            end
          end
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_sms.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms.title).to include('from=>en to=>pl text=>Sms')
        end

        it '#translate_subtitle' do
          question_sms.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms.subtitle).to equal(nil)
        end

        it '#translate_body' do
          question_sms.translate_body(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms.body['data']).to include(
            {
              'payload' => '',
              'value' => '1',
              'original_text' => ''
            },
            {
              'payload' => 'from=>en to=>pl text=>example2',
              'value' => '',
              'original_text' => 'example2'
            }
          )
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_sms, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end
end
