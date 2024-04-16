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

        it '#translate_subtitle' do
          question_sms_information.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_sms_information.subtitle).to include('from=>en to=>pl text=>Name screen')
        end
      end

      describe '#question_variables' do
        it 'returns empty variables list' do
          expect(question_sms_information.question_variables).to match_array []
        end
      end

      describe '#schedule_at' do
        context 'when \"from last question\" scope is provided' do
          let!(:user) { create(:user, :with_phone) }
          let!(:intervention) { create(:intervention) }
          let!(:question_group_initial) { build(:question_group_initial) }
          let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
          let!(:question_group) { create(:sms_question_group, session: session) }
          let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
          let!(:user_session) { create(:sms_user_session, user: user, session: session) }
          let!(:question_sms1_information) { create(:question_sms_information, question_group: question_group) }
          let!(:answer1) { create(:answer_sms_information, question: question_sms1_information, user_session: user_session) }
          let!(:question_sms2_information) do
            create(:question_sms_information,
                   question_group: question_group,
                   sms_schedule: { period: 'from_last_question',
                                   day_of_period: '1',
                                   time: { exact: '8:00 AM' } })
          end

          it 'returns proper date' do
            date = (question_sms1_information.answers.last.created_at + 1.day).change(hour: 8)
            expect(question_sms2_information.schedule_in(user_session)).to eq date
          end
        end

        context 'when \"from session start\" scope is provided' do
          let!(:user) { create(:user, :with_phone) }
          let!(:intervention) { create(:intervention) }
          let!(:question_group_initial) { build(:question_group_initial) }
          let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
          let!(:question_group) { create(:sms_question_group, session: session) }
          let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
          let!(:user_session) { create(:sms_user_session, user: user, session: session) }
          let(:question_sms1_information) { create(:question_sms_information, question_group: question_group) }
          let(:question_sms2_information) do
            create(:question_sms_information,
                   question_group: question_group,
                   sms_schedule: { period: 'from_user_session_start',
                                   day_of_period: '3',
                                   time: { exact: '8:00 AM' } })
          end

          it 'returns proper date' do
            date = (user_session.created_at + 3.days).change(hour: 8)
            expect(question_sms2_information.schedule_in(user_session)).to eq date
          end
        end
      end
    end
  end
end
