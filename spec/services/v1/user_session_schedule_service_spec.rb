# frozen_string_literal: true

RSpec.describe V1::UserSessionScheduleService do
  let!(:intervention) { create(:intervention) }
  let!(:user) { create(:user, :participant) }
  let!(:first_session) { create(:session, intervention: intervention, position: 1) }
  let!(:second_session) { create(:session, intervention: intervention, schedule: schedule, schedule_payload: schedule_payload, position: 2, schedule_at: schedule_at) }
  let!(:user_session) { create(:user_session, user: user, session: first_session) }
  let(:schedule) { 'after_fill' }
  let(:schedule_payload) { 2 }
  let(:schedule_at) { (DateTime.now + 4.days).to_s }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  before do
    allow(message_delivery).to receive(:deliver_later)
    ActiveJob::Base.queue_adapter = :test
  end

  context 'user session schedule service' do
    context 'when session has schedule after fill' do
      after { described_class.new(user_session).schedule }

      it 'calls correct method' do
        expect_any_instance_of(described_class).to receive(:after_fill_schedule)
      end

      it 'sends an email' do
        expect(SessionMailer).to receive(:inform_to_an_email).with(second_session, user.email).and_return(message_delivery)
      end
    end

    context 'when session has schedule days after fill' do
      let(:schedule) { 'days_after_fill' }
      let(:expected_timestamp) { Time.current + schedule_payload.days }

      it 'calls correct method' do
        expect_any_instance_of(described_class).to receive(:days_after_fill_schedule)
        described_class.new(user_session).schedule
      end

      it 'schedules on correct time' do
        expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionEmailScheduleJob)
                                               .with(second_session.id, user.id)
                                               .at(a_value_within(1.second).of(expected_timestamp))
      end
    end

    context 'when session has schedule exact date' do
      let(:schedule) { 'exact_date' }

      it 'calls correct method' do
        expect_any_instance_of(described_class).to receive(:exact_date_schedule)
        described_class.new(user_session).schedule
      end

      it 'schedules on correct time' do
        expect { described_class.new(user_session).schedule }.to have_enqueued_job(SessionEmailScheduleJob)
                                                                   .with(second_session.id, user.id)
                                                                   .at(a_value_within(1.second).of(Date.parse(schedule_at).noon))
      end
    end
  end
end
