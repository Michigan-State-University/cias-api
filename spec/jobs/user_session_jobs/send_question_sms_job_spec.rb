# frozen_string_literal: true

RSpec.describe UserSessionJobs::SendQuestionSmsJob, type: :job do
  subject { described_class.perform_now(user.id, question.id, user_session.id) }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(
      {
        status: 200
      }
    )
  end

  describe '#perform_later' do
    let!(:intervention) { create(:intervention) }
    let!(:question_group_initial) { build(:question_group_initial) }
    let!(:session) { create(:sms_session, sms_code: 'SMS_CODE_1', intervention: intervention, question_group_initial: question_group_initial) }
    let!(:question_group) { create(:sms_question_group, session: session) }
    let!(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
    let!(:user_session) { create(:sms_user_session, user: user, session: session) }

    context 'when user has no pending answers' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }

      context 'when desired question is SmsInformation' do
        let!(:question) { create(:question_sms_information, question_group: question_group) }

        it 'sends sms' do
          expect { subject }.to change(Message, :count)
        end
      end

      context 'when desired question is Sms' do
        let!(:question) { create(:question_sms, question_group: question_group) }

        it 'sends sms' do
          expect { subject }.to change(Message, :count)
        end
      end
    end

    context 'when user has pending answers' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: true) }

      context 'when desired question is SmsInformation' do
        let!(:question) do
          create(:question_sms_information,
                 question_group: question_group,
                 sms_schedule: {
                   period: 'daily',
                   time: {
                     exact: '8:00 AM'
                   }
                 })
        end

        it 'does not send sms' do
          expect { subject }.not_to change(Message, :count)
        end

        context 'when there is time for scheduling next job' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules new sending job' do
            travel_to question.schedule_in(user_session).change({ hour: 12 }) do
              expect { subject }.to have_enqueued_job(described_class)
            end
          end
        end

        context 'when there is no time for scheduling next job' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule new sending job' do
            travel_to question.schedule_in(user_session).change({ hour: 23, min: 59 }) do
              expect { subject }.not_to have_enqueued_job(described_class)
            end
          end

          it 'creates new answer' do
            travel_to question.schedule_in(user_session).change({ hour: 23, min: 59 }) do
              expect { subject }.to change(Answer::SmsInformation, :count).by(1)
            end
          end
        end
      end

      context 'when desired question is Sms' do
        let!(:question) do
          create(:question_sms,
                 question_group: question_group,
                 sms_schedule: {
                   period: 'daily',
                   time: {
                     exact: '8:00 AM'
                   }
                 })
        end

        it 'does not send sms' do
          expect { subject }.not_to change(Message, :count)
        end

        context 'when there is time for scheduling next job' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules new sending job' do
            travel_to question.schedule_in(user_session) + 1.day do
              expect { subject }.to have_enqueued_job(described_class)
            end
          end
        end

        context 'when there is no time for scheduling next job' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule new sending job' do
            travel_to question.schedule_in(user_session) + 3.days do
              expect { subject }.not_to have_enqueued_job(described_class)
            end
          end
        end
      end
    end
  end
end
