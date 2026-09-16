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

  describe 'module inclusion' do
    it 'includes SmsCampaign::FinishUserSessionHelper' do
      expect(described_class.ancestors).to include(SmsCampaign::FinishUserSessionHelper)
    end
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

        it 'associates message with question' do
          subject
          message = Message.last
          expect(message.question).to eq(question)
        end

        it 'calls finish_user_session_if_that_was_last_question' do
          job_instance = described_class.new
          expect(job_instance).to receive(:finish_user_session_if_that_was_last_question).with(user_session, question)
          allow(described_class).to receive(:new).and_return(job_instance)
          allow(job_instance).to receive(:perform).and_call_original

          job_instance.perform(user.id, question.id, user_session.id, false)
        end
      end

      context 'when desired question is Sms' do
        let!(:question) { create(:question_sms, question_group: question_group) }

        it 'sends sms' do
          expect { subject }.to change(Message, :count)
        end

        it 'associates message with question' do
          subject
          message = Message.last
          expect(message.question).to eq(question)
        end

        it 'does not call finish user session if that wasn\'t last question for Sms questions' do
          described_class.perform_now(user.id, question.id, user_session.id, false)
          expect(user_session.reload.finished_at).to be_nil
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
            lest_question_in_group = question_group_initial.questions.order(:position).last
            expect do
              described_class.perform_now(user.id, lest_question_in_group.id, user_session.id, false)
            end.to change { user_session.reload.number_of_repetitions }.by(1)
          end

          it 'does not increment number_of_repetitions when not last question in initial group' do
            expect do
              described_class.perform_now(user.id, first_question.id, user_session.id, false)
            end.not_to change { user_session.reload.number_of_repetitions }
          end
        end

        it 'does not increment number_of_repetitions for non-initial question groups' do
          regular_question_group = create(:sms_question_group, session: session)
          regular_question = create(:question_sms, question_group: regular_question_group)

          expect do
            described_class.perform_now(user.id, regular_question.id, user_session.id, false)
          end.not_to change { user_session.reload.number_of_repetitions }
        end
      end
    end

    describe '#should_increment_number_or_repetition?' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }
      let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
      let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 1) }
      let(:job_instance) { described_class.new }

      context 'when question group is not initial' do
        let!(:regular_question_group) { create(:sms_question_group, session: session) }
        let!(:question) { create(:question_sms_information, question_group: regular_question_group) }

        it 'returns false' do
          expect(job_instance.send(:should_increment_number_or_repetition?, question)).to be false
        end
      end

      context 'when question group is initial but not last question' do
        let!(:first_question) { create(:question_sms_information, question_group: question_group_initial, position: 1) }
        let!(:last_question) { create(:question_sms_information, question_group: question_group_initial, position: 2) }

        it 'returns false for first question' do
          expect(job_instance.send(:should_increment_number_or_repetition?, first_question)).to be false
        end

        it 'returns true for last question' do
          expect(job_instance.send(:should_increment_number_or_repetition?, last_question)).to be true
        end
      end

      context 'when question group is initial and is last question' do
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }

        it 'returns true' do
          expect(job_instance.send(:should_increment_number_or_repetition?, question)).to be true
        end
      end
    end

    describe '#last_question_in_the_group?' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }
      let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
      let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 1) }
      let(:job_instance) { described_class.new }

      context 'when question is the last in the group' do
        let!(:first_question) { create(:question_sms_information, question_group: question_group_initial, position: 1) }
        let!(:last_question) { create(:question_sms_information, question_group: question_group_initial, position: 2) }

        it 'returns true for last question' do
          expect(job_instance.send(:last_question_in_the_group?, last_question)).to be true
        end

        it 'returns false for first question' do
          expect(job_instance.send(:last_question_in_the_group?, first_question)).to be false
        end
      end

      context 'when there is only one question in the group' do
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }

        it 'returns true' do
          expect(job_instance.send(:last_question_in_the_group?, question)).to be true
        end
      end
    end

    describe 'number_of_repetitions incrementation integration' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }
      let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
      let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 1) }

      context 'when sending last question in initial group' do
        let!(:first_question) { create(:question_sms_information, question_group: question_group_initial, position: 1) }
        let!(:last_question) { create(:question_sms_information, question_group: question_group_initial, position: 2) }

        it 'increments number_of_repetitions and updates user_session' do
          expect do
            described_class.perform_now(user.id, last_question.id, user_session.id, false)
          end.to change { user_session.reload.number_of_repetitions }.from(1).to(2)
        end

        it 'saves the user_session with updated repetitions' do
          described_class.perform_now(user.id, last_question.id, user_session.id, false)
          expect(user_session.reload.number_of_repetitions).to eq(2)
        end
      end

      context 'when sending non-last question in initial group' do
        let!(:first_question) { create(:question_sms_information, question_group: question_group_initial, position: 1) }
        let!(:last_question) { create(:question_sms_information, question_group: question_group_initial, position: 2) }

        it 'does not increment number_of_repetitions' do
          expect do
            described_class.perform_now(user.id, first_question.id, user_session.id, false)
          end.not_to change { user_session.reload.number_of_repetitions }
        end
      end
    end

    describe 'finish_user_session_if_that_was_last_question integration' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }
      let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }

      context 'when question is SmsInformation and conditions are met to finish session' do
        let!(:question_group_initial) do
          build(:question_group_initial, sms_schedule: {
                  'number_of_repetitions' => 2,
                  'messages_after_limit' => 3
                })
        end
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }
        let!(:user_session) do
          create(:sms_user_session, user: user, session: session, number_of_repetitions: 2,
                                    max_repetitions_reached_at: 1.day.ago)
        end

        before do
          questions = create_list(:question_sms_information, 3, question_group: question_group_initial)
          questions.each do |q|
            create(:message, :with_code, question: q, created_at: 12.hours.ago)
          end
        end

        it 'finishes the user session when called for SmsInformation question' do
          expect do
            described_class.perform_now(user.id, question.id, user_session.id, false)
          end.to change { user_session.reload.finished_at }.from(nil)
        end
      end

      context 'when question is Sms type' do
        let!(:question) { create(:question_sms, question_group: question_group_initial) }
        let!(:user_session) { create(:sms_user_session, user: user, session: session, number_of_repetitions: 2) }

        it 'does not call finish_user_session_if_that_was_last_question' do
          described_class.perform_now(user.id, question.id, user_session.id, false)
          expect(user_session.reload.finished_at).to be_nil
        end
      end
    end

    describe 'Message creation with question association' do
      let!(:user) { create(:user, :with_phone, pending_sms_answer: false) }
      let!(:session) { create(:sms_session, sms_codes: [sms_code], intervention: intervention, question_group_initial: question_group_initial) }
      let!(:user_session) { create(:sms_user_session, user: user, session: session) }

      context 'when creating message for any question type' do
        let!(:question) { create(:question_sms_information, question_group: question_group_initial) }

        it 'creates message with question association' do
          expect do
            described_class.perform_now(user.id, question.id, user_session.id, false)
          end.to change(Message, :count).by(1)

          message = Message.last
          expect(message.question).to eq(question)
          expect(message.body).to eq(question.subtitle)
          expect(message.phone).to eq(user.full_number)
        end
      end
    end
  end
end
