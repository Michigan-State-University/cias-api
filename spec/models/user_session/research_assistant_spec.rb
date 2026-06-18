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
  end
end
