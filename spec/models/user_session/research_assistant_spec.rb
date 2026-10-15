# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSession::ResearchAssistant, type: :model do
  subject(:ra_user_session) { create(:ra_user_session) }

  describe 'inheritance' do
    it 'inherits from UserSession' do
      expect(described_class.superclass).to eq(UserSession)
    end
  end

  describe 'associations' do
    it 'belongs to fulfilled_by (optional)' do
      expect(ra_user_session).to respond_to(:fulfilled_by)
      expect(ra_user_session.fulfilled_by).to be_nil
    end

    it 'can be assigned a fulfiller' do
      researcher = create(:user, :confirmed, :researcher)
      ra_user_session.update!(fulfilled_by: researcher)
      expect(ra_user_session.reload.fulfilled_by).to eq(researcher)
    end
  end

  describe '#finish' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    context 'when not already finished' do
      it 'sets finished_at timestamp' do
        expect(ra_user_session.finished_at).to be_nil
        ra_user_session.finish
        expect(ra_user_session.finished_at).to be_present
        expect(ra_user_session.finished_at).to be_within(1.second).of(DateTime.current)
      end

      it 'enqueues AfterFinishUserSessionJob' do
        expect do
          ra_user_session.finish
        end.to have_enqueued_job(AfterFinishUserSessionJob)
      end
    end

    context 'when already finished' do
      before do
        ra_user_session.update!(finished_at: 1.day.ago)
      end

      it 'does not update finished_at' do
        original_finished_at = ra_user_session.finished_at
        ra_user_session.finish
        expect(ra_user_session.finished_at).to eq(original_finished_at)
      end
    end

    context 'when closed by an inactivity timeout' do
      it 'records why the session was closed' do
        expect { ra_user_session.finish(reason: 'inactivity_timeout') }
          .to change { ra_user_session.reload.finish_reason }.from(nil).to('inactivity_timeout')
      end

      it 'still generates the reports' do
        expect { ra_user_session.finish(reason: 'inactivity_timeout') }
          .to have_enqueued_job(AfterFinishUserSessionJob)
          .with(ra_user_session.id, ra_user_session.session.intervention)
      end
    end
  end

  describe '#on_answer' do
    let(:question_group) { create(:question_group, session: ra_user_session.session) }
    let(:question) { create(:question_single, :start_autofinish_timer_on, question_group: question_group) }

    before do
      ActiveJob::Base.queue_adapter = :test
      create(:answer_single, question: question, user_session: ra_user_session)
    end

    context 'when autofinish is off and the threshold was passed' do
      it 'schedules the inactivity timeout' do
        expect { ra_user_session.on_answer }
          .to have_enqueued_job(UserSessionTimeoutJob)
          .with(ra_user_session.id, 'inactivity_timeout')
      end
    end
  end
end
