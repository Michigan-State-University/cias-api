# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::Publish do
  let!(:intervention) { create(:intervention, published_at: nil) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question) { create(:question_single, question_group: question_group) }
  let!(:answers) { create_list(:answer_single, 4, question: question) }
  let!(:second_session) { create(:session, intervention: intervention, schedule: schedule, schedule_at: schedule_at, schedule_payload: schedule_payload) }
  let!(:third_session) { create(:session, intervention: intervention, schedule: 'days_after', schedule_payload: days_after_payload) }
  let(:schedule) { 'after_fill' }
  let(:schedule_at) { Date.current + 10.days }
  let(:schedule_payload) { 7 }
  let(:days_after_payload) { 5 }

  before do
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  context 'intervention status change publish' do
    it 'calls correct methods on execute' do
      expect_any_instance_of(described_class).to receive(:timestamp_published_at)
      expect_any_instance_of(described_class).to receive(:calculate_days_after_schedule)
      expect_any_instance_of(described_class).to receive(:delete_draft_answers)
      described_class.new(intervention).execute
    end

    it 'sets correct publish at timestamp' do
      described_class.new(intervention).execute
      expect(intervention.reload.published_at.to_s).to eq(Time.current.to_s)
    end

    it 'correctly clears all test answers' do
      described_class.new(intervention).execute
      expect(intervention.sessions.first.question_groups.first.questions.first.answers.reload.size).to eq(0)
    end

    context 'when we have preview data' do
      let!(:preview_session_user) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }
      let!(:preview_user_phone) { create(:phone, :confirmed, user: preview_session_user) }
      let!(:user_log_request) { create(:user_log_request, user: preview_session_user) }
      let!(:user_session) { create(:user_session, user_id: preview_session_user.id, session_id: session.id) }

      it 'clear preview users and preview user sessions' do
        described_class.new(intervention).execute
        expect(User.exists?(id: preview_session_user.id)).to eq false
        expect(UserSession.exists?(id: user_session.id)).to eq false
        expect(UserLogRequest.exists?(user_id: preview_session_user.id)).to eq false
        expect(Phone.exists?(id: preview_user_phone.id)).to eq false
      end
    end
  end

  context 'days after schedule calculation' do
    context 'previous session has after_fill schedule' do
      it 'correctly calculates schedule at for days after' do
        described_class.new(intervention).execute
        expect(third_session.reload.schedule_at).to eq(Date.current + days_after_payload.days)
      end

      context 'number of days equal nil' do
        let(:days_after_payload) { nil }

        it 'set default value' do
          described_class.new(intervention).execute
          expect(third_session.reload.schedule_at).to eq(Date.current)
        end
      end
    end


    context 'previous session has exact_date schedule' do
      let(:schedule) { 'exact_date' }

      it 'correctly calculates schedule at for days after' do
        described_class.new(intervention).execute
        expect(third_session.reload.schedule_at).to eq(schedule_at + days_after_payload.days)
      end

      context 'previous session has days_after_fill schedule' do
        let(:schedule) { 'days_after_fill' }

        it 'correctly calculates schedule at for days after' do
          described_class.new(intervention).execute
          expect(third_session.reload.schedule_at).to eq(Date.current + schedule_payload.days + days_after_payload.days)
        end
      end
    end
  end
end
