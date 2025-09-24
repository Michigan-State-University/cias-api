# frozen_string_literal: true

RSpec.describe UserSessionJobs::SendQuestionSmsJob, type: :job do
  subject { described_class.perform_now(user.id, question.id, user_session.id, false) }

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
    let!(:sms_code) { build(:sms_code) }
    let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
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
        let!(:previous_question) { create(:question_sms, question_group: question_group) }
        let!(:previous_question_answer) { create(:answer_sms, question: previous_question, user_session: user_session) }
        let!(:question) { create(:question_sms_information, question_group: question_group) }

        it 'sends sms' do
          expect { subject }.to change(Message, :count)
        end
      end

      context 'when desired question is Sms' do
        let!(:previous_question) { create(:question_sms, question_group: question_group) }
        let!(:previous_question_answer) { create(:answer_sms, question: previous_question, user_session: user_session) }
        let!(:question) { create(:question_sms, question_group: question_group) }

        it 'does not send sms' do
          expect { subject }.not_to change(Message, :count)
        end

        context 'when there is time for scheduling next job' do
          include ActiveSupport::Testing::TimeHelpers

          it 'schedules new sending job' do
            travel_to DateTime.current.change({ hour: 12 }) do
              expect { subject }.to have_enqueued_job(described_class)
            end
          end
        end

        context 'when there is no time for scheduling next job' do
          include ActiveSupport::Testing::TimeHelpers

          it 'does not schedule new sending job' do
            travel_to DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)).change({ hour: 23, min: 59 }) do
              expect { subject }.not_to have_enqueued_job(described_class)
            end
          end

          it 'does not create new answer' do
            travel_to DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)).change({ hour: 23, min: 59 }) do
              expect { subject }.not_to change(Answer::SmsInformation, :count)
            end
          end
        end
      end
    end

    context 'when number of repetitions functionality' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }
      let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }

      context 'when user session has not reached maximum repetitions' do
        let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 1) }
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }

        it 'allows sending SMS' do
          expect { subject }.to change(Message, :count).by(1)
        end

        context 'when question is last in initial group' do
          let!(:first_question) { create(:question_sms_information, question_group: question_group_initial, position: 1) }
          let!(:last_question) { create(:question_sms_information, question_group: question_group_initial, position: 2) }

          it 'increments number_of_repetitions when last question in initial group' do
            expect {
              described_class.perform_now(user.id, last_question.id, user_session.id, false)
            }.to change { user_session.reload.number_of_repetitions }.by(1)
          end

          it 'does not increment number_of_repetitions when not last question in initial group' do
            expect {
              described_class.perform_now(user.id, first_question.id, user_session.id, false)
            }.not_to change { user_session.reload.number_of_repetitions }
          end
        end

        it 'does not increment number_of_repetitions for non-initial question groups' do
          regular_question_group = create(:sms_question_group, session: session)
          regular_question = create(:question_sms, question_group: regular_question_group)

          expect {
            described_class.perform_now(user.id, regular_question.id, user_session.id, false)
          }.not_to change { user_session.reload.number_of_repetitions }
        end
      end

      context 'when user session has reached maximum repetitions' do
        let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 3) }
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }

        it 'does not send SMS when max repetitions reached' do
          expect { subject }.not_to change(Message, :count)
        end
      end

      context 'when user session exceeds maximum repetitions' do
        let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 5) }
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }

        it 'does not send SMS when repetitions exceeded' do
          expect { subject }.not_to change(Message, :count)
        end
      end
    end
  end
end
