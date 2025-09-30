# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::SessionService, type: :service do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let!(:session1) { create(:session, intervention: intervention, schedule: 'immediately') }
  let!(:session2) { create(:session, intervention: intervention, schedule: 'days_after') }
  let!(:session3) { create(:session, intervention: intervention, schedule: 'after_fill') }

  let(:service) { described_class.new(user, intervention.id) }

  describe '#update_all_schedules' do
    let(:schedule_attributes) do
      {
        schedule: 'exact_date',
        schedule_payload: nil,
        schedule_at: '2025-12-25 10:00:00'
      }
    end

    it 'updates all sessions with the provided attributes' do
      service.update_all_schedules(schedule_attributes)

      session1.reload
      session2.reload
      session3.reload

      expect(session1.schedule).to eq('exact_date')
      expect(session2.schedule).to eq('exact_date')
      expect(session3.schedule).to eq('exact_date')
      expect(session1.schedule_at.to_s).to include('2025-12-25')
      expect(session2.schedule_at.to_s).to include('2025-12-25')
      expect(session3.schedule_at.to_s).to include('2025-12-25')
    end

    it 'returns all sessions ordered by position' do
      result = service.update_all_schedules(schedule_attributes)

      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.count).to eq(3)
      expect(result.pluck(:id)).to eq([session1.id, session2.id, session3.id])
    end

    it 'updates schedule_payload when provided' do
      attributes = {
        schedule: 'days_after',
        schedule_payload: 5,
        schedule_at: nil
      }

      service.update_all_schedules(attributes)

      session1.reload
      session2.reload
      session3.reload

      expect(session1.schedule).to eq('days_after')
      expect(session2.schedule).to eq('days_after')
      expect(session3.schedule).to eq('days_after')
      expect(session1.schedule_payload).to eq(5)
      expect(session2.schedule_payload).to eq(5)
      expect(session3.schedule_payload).to eq(5)
    end

    it 'handles empty attributes gracefully' do
      expect { service.update_all_schedules({}) }.not_to raise_error
    end

    context 'when intervention has no sessions' do
      let(:empty_intervention) { create(:intervention, user: user) }
      let(:empty_service) { described_class.new(user, empty_intervention.id) }

      it 'returns empty relation' do
        result = empty_service.update_all_schedules(schedule_attributes)

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(0)
      end
    end
  end
end
