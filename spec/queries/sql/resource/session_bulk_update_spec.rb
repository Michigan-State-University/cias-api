# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SessionBulkUpdate', type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:intervention) { create(:intervention) }
  let!(:session1) { create(:session, intervention: intervention, schedule: 'immediately') }
  let!(:session2) { create(:session, intervention: intervention, schedule: 'immediately') }
  let!(:session3) { create(:session, intervention: intervention, schedule: 'days_after') }

  let(:batch_update_params) do
    [
      {
        id: session1.id,
        schedule: 'after_fill',
        schedule_payload: nil,
        schedule_at: nil
      },
      {
        id: session2.id,
        schedule: 'exact_date',
        schedule_payload: nil,
        schedule_at: '2025-12-25T10:00:00Z'
      },
      {
        id: session3.id,
        schedule: 'days_after',
        schedule_payload: 7,
        schedule_at: '2025-09-23T08:00:00Z'
      }
    ]
  end

  before do
    # Ensure sessions are created with initial values
    session1
    session2
    session3
  end

  describe 'bulk update execution' do
    it 'updates multiple sessions correctly' do
      SqlQuery.new(
        'resource/session_bulk_update',
        values: batch_update_params
      ).execute

      # Reload sessions to get updated data
      session1.reload
      session2.reload
      session3.reload

      # Verify updates
      expect(session1.schedule).to eq('after_fill')
      expect(session1.schedule_payload).to be_nil
      expect(session1.schedule_at).to be_nil

      expect(session2.schedule).to eq('exact_date')
      expect(session2.schedule_payload).to be_nil
      expect(session2.schedule_at.to_date).to eq(Date.parse('2025-12-25'))

      expect(session3.schedule).to eq('days_after')
      expect(session3.schedule_payload).to eq(7)
      expect(session3.schedule_at.to_date).to eq(Date.parse('2025-09-23'))
    end

    it 'updates the updated_at timestamp' do
      old_timestamps = [session1.updated_at, session2.updated_at, session3.updated_at]

      travel_to 1.hour.from_now do
        SqlQuery.new(
          'resource/session_bulk_update',
          values: batch_update_params
        ).execute
      end

      session1.reload
      session2.reload
      session3.reload

      expect(session1.updated_at).to be > old_timestamps[0]
      expect(session2.updated_at).to be > old_timestamps[1]
      expect(session3.updated_at).to be > old_timestamps[2]
    end

    it 'handles null values correctly' do
      null_params = [
        {
          id: session1.id,
          schedule: 'after_fill',
          schedule_payload: nil,
          schedule_at: nil
        }
      ]

      SqlQuery.new(
        'resource/session_bulk_update',
        values: null_params
      ).execute

      session1.reload
      expect(session1.schedule_payload).to be_nil
      expect(session1.schedule_at).to be_nil
    end
  end
end
