# frozen_string_literal: true

RSpec.describe V1::Sms::Replay do
  include ActiveJob::TestHelper

  subject { described_class.call(from, to, body) }

  let!(:user) { create(:user, :confirmed, :participant) }
  let(:from) { '+48555777888' }
  let(:to) { '+48555444777' }

  context 'sending STOP message' do
    let(:body) { 'STOP' }
    let!(:session) { create(:session) }

    before do
      10.times do |delay|
        SmsPlans::SendSmsJob.set(wait_until: (delay + 1).days.from_now).perform_later(from, 'example content', nil, user.id, false, session.id)
      end
    end

    it 'call the method to clear jobs' do
      expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
      subject
    end

    context 'stop with white spaces' do
      let(:body) { ' stop ' }

      it 'call the method to clear jobs' do
        expect_any_instance_of(described_class).to receive(:delete_messaged_for).with(from)
        subject
      end
    end

    context 'body different than stop' do
      let(:body) { ' help ' }

      it 'call the method to clear jobs' do
        expect_any_instance_of(described_class).not_to receive(:delete_messaged_for).with(from)
        subject
      end
    end
  end

  context 'sending text, which matches sms_code of session' do
    context 'when session session code has proper length' do
      let(:body) { 'SMS_CODE' }

      it 'creates new user session' do
        expect_any_instance_of(described_class).to receive(:handle_message_with_sms_code)
        subject
      end
    end

    context 'when session session code does not have proper length' do
      let(:body) { 'SMS' }

      it 'does not create new user session' do
        expect_any_instance_of(described_class).not_to receive(:handle_message_with_sms_code)
        subject
      end
    end
  end

  describe '#schedule_or_finish' do
    let(:intervention) { create(:intervention) }
    let(:session) { create(:sms_session, intervention: intervention) }
    let(:question_group_initial) do
      create(:question_group_initial, session: session, sms_schedule: {
               'number_of_repetitions' => 3,
               'messages_after_limit' => 5
             })
    end
    let(:question) { create(:question_sms_information, question_group: question_group_initial) }
    let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
    let(:replay_service) { described_class.new(from, to, 'test message') }

    context 'when it was the last question in user session' do
      let(:user_session) do
        create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                  number_of_repetitions: 3, max_repetitions_reached_at: 1.day.ago)
      end

      before do
        questions = create_list(:question_sms_information, 7, question_group: question_group_initial)
        questions.each do |q|
          create(:message, :with_code, question: q, created_at: 12.hours.ago)
        end
      end

      it 'finishes the user session' do
        expect do
          replay_service.send(:schedule_or_finish, user_session)
        end.to change { user_session.reload.finished_at }.from(nil)
      end
    end

    context 'when it was not the last question in user session' do
      let(:user_session) do
        create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                  number_of_repetitions: 2) # Below limit
      end

      it 'does not finish the user session' do
        expect do
          replay_service.send(:schedule_or_finish, user_session)
        end.not_to change { user_session.reload.finished_at }
      end
    end

    context 'when repetitions reached but messages under limit' do
      let(:user_session) do
        create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                  number_of_repetitions: 3, max_repetitions_reached_at: 1.day.ago)
      end

      before do
        # Create only 3 messages assigned to different questions, below the limit of 5
        questions = create_list(:question_sms_information, 3, question_group: question_group_initial)
        questions.each do |q|
          create(:message, :with_code, question: q, created_at: 12.hours.ago)
        end
      end

      it 'does not finish the user session' do
        expect do
          replay_service.send(:schedule_or_finish, user_session)
        end.not_to change { user_session.reload.finished_at }
      end
    end
  end

  describe 'FinishUserSessionHelper integration' do
    let(:intervention) { create(:intervention) }
    let(:session) { create(:sms_session, intervention: intervention) }
    let(:question_group_initial) do
      create(:question_group_initial, session: session)
    end
    let!(:question) { create(:question_sms_information, question_group: question_group_initial) }
    let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

    it 'includes FinishUserSessionHelper module' do
      expect(described_class.ancestors).to include(SmsCampaign::FinishUserSessionHelper)
    end

    context 'when repetitions reached and message limit reached' do
      let(:user_session) do
        create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                  number_of_repetitions: 3, max_repetitions_reached_at: 1.day.ago)
      end
      let(:replay_service) { described_class.new(from, to, 'test answer') }

      before do
        questions = create_list(:question_sms_information, 7, question_group: question_group_initial)
        questions.each do |q|
          create(:message, :with_code, question: q, created_at: 12.hours.ago)
        end
      end

      it 'finishes user session when conditions are met' do
        expect do
          replay_service.send(:schedule_or_finish, user_session)
        end.to change { user_session.reload.finished_at }.from(nil)
      end
    end

    context 'when repetitions not reached' do
      let(:user_session) do
        create(:sms_user_session, user: user, session: session, user_intervention: user_intervention,
                                  number_of_repetitions: 2)
      end
      let(:replay_service) { described_class.new(from, to, 'test answer') }

      it 'does not finish user session when repetitions not reached' do
        expect do
          replay_service.send(:schedule_or_finish, user_session)
        end.not_to change { user_session.reload.finished_at }
      end
    end
  end
end
