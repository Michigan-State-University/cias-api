# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSession, type: :model do
  context 'UserSession' do
    subject { create(:user_session) }

    it { should belong_to(:user) }
    it { should belong_to(:session) }
    it { should have_many(:answers) }
    it { should be_valid }
  end

  context 'instance methods' do
    context 'user session finish behaviour' do
      let(:user_session) { create(:user_session, finished_at: finished_at) }
      let(:user_session_schedule_service) { instance_double(V1::UserSessionScheduleService) }
      let(:finished_at) { nil }

      before do
        allow(V1::UserSessionScheduleService).to receive(:new).with(user_session).and_return(user_session_schedule_service)
        ActiveJob::Base.queue_adapter = :test
      end

      context 'user session finish' do
        it 'calls user schedule service correctly' do
          expect(user_session_schedule_service).to receive(:schedule)
          user_session.finish
        end

        it 'does not call user schedule service when send email flag is off' do
          expect(user_session_schedule_service).not_to receive(:schedule)
          user_session.finish(send_email: false)
        end

        context 'user has been finished before' do
          let(:finished_at) { DateTime.now }

          it 'does not call user schedule service ' do
            expect(user_session_schedule_service).not_to receive(:schedule)
            user_session.finish
          end
        end
      end

      context 'user session on answer' do
        let(:user_session) { create(:user_session, timeout_job_id: timeout_job_id) }
        let(:expected_timestamp) { Time.current + 1.day }
        let(:timeout_job_id) { nil }

        context 'timeout_job_id is nil' do
          it 'schedules session timeout correctly' do
            expect { user_session.on_answer }.to have_enqueued_job(UserSessionTimeoutJob)
                                                   .with(user_session.id)
                                                   .at(a_value_within(1.second).of(expected_timestamp))
          end

          it 'does not call #cancel without timout_job_id' do
            expect(UserSessionTimeoutJob).not_to receive(:cancel)
            user_session.on_answer
          end
        end

        context 'when timeout_job_id is set' do
          let(:timeout_job_id) { 'test_timeout_job' }

          it 'triggers #cancel on UserSessionTimeoutJob with timeout_job_id' do
            expect(UserSessionTimeoutJob).to receive(:cancel).with(timeout_job_id)
            user_session.on_answer
          end
        end
      end
    end
  end
end
