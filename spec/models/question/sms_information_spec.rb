# frozen_string_literal: true

RSpec.describe Question::SmsInformation, type: :model do
  describe 'Question::SmsInformation' do
    subject(:question_sms_information) { build(:question_sms_information) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_sms_information, question_group: question_group) }

      it_behaves_like 'can be assigned to sms session'
      it_behaves_like 'cannot be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_sms_information) { create(:question_sms_information) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_sms_information.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_sms_information.variable_clone_prefix(%w[clone_question_slider_var
                                                                   clone1_question_slider_var])).to eq(nil)
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_sms_information.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms_information.title).to include('from=>en to=>pl text=>Name screen')
        end

        it '#translate_subtitle' do
          question_sms_information.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms_information.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns empty variables list' do
          expect(question_sms_information.question_variables).to match_array []
        end
      end


      describe '#schedule_at' do
        context 'when weekly period is provided' do
          let(:question_sms_information) { create(:question_sms_information,
                                      sms_schedule: { "period": 'weekly',
                                                      "day_of_period": 'monday',
                                                      "time": { exact: '8:00 AM' } })}
          it 'returns proper date' do
            date = Date.current.wday === 1 ?
                     DateTime.current.change({hour: 8}) :
                     DateTime.commercial(Date.today.year, 1+Date.today.cweek, 1).change({hour: 8})
            expect(question_sms_information.schedule_at).to eq date
          end
        end

        context 'when monthly period is provided' do
          let(:question_sms_information) { create(:question_sms_information,
                                      sms_schedule: { "period": 'monthly',
                                                      "day_of_period": '1',
                                                      "time": { exact: '8:00 AM' } })}
          it 'returns proper date' do
            date = Date.current.mday === 1 ?
                     DateTime.current.change({hour: 8}) :
                     DateTime.current.change({month: DateTime.current.month + 1, day: 1, hour: 8})
            expect(question_sms_information.schedule_at).to eq date
          end
        end

        context 'when daily period is provided' do
          let(:question_sms_information) { create(:question_sms_information,
                                      sms_schedule: { "period": 'daily',
                                                      "day_of_period": '1',
                                                      "time": { exact: '8:00 AM' } })}
          it 'returns proper date' do
            date = DateTime.current.hour >= 8 && DateTime.current.minute >= 0 && DateTime.current.second >= 0 ?
                     DateTime.current.change({day: DateTime.current.day + 1, hour: 8}) :
                     DateTime.current.change({hour: 8})
            expect(question_sms_information.schedule_at).to eq date
          end
        end
      end
    end
  end
end
