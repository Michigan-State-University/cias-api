# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention::Schedule do
  let(:problem) { create(:problem, published_at: Time.current) }
  let(:interventions) do
    interventions = create_list(:intervention, 4, problem_id: problem.id, schedule: 'days_after', schedule_payload: 7)
    first_inter = interventions.first
    first_inter.update(schedule: nil, schedule_payload: nil)
    interventions
  end

  let(:execute_days_after) { Intervention::Schedule.new(interventions, problem.published_at).days_after }

  context 'days_after' do
    it 'are days_after' do
      execute_days_after

      dates_arr = []
      interventions.size.times do |iterate|
        dates_arr.push(Date.current + (7 * iterate))
      end
      expect(interventions.pluck(:schedule_at)).to match_array(dates_arr)
    end

    it 'mix second is_days_after_fill' do
      interventions.second.update(schedule: 'days_after_fill', schedule_payload: nil)
      execute_days_after

      expect(interventions.first.schedule_at).to eq Date.current
      expect(interventions[1..-1].pluck(:schedule_at).uniq).to match_array([nil])
    end

    it 'mix after is_day_after no schedule_at' do
      interventions[-2].update(schedule: 'days_after_fill', schedule_payload: 5)
      execute_days_after

      expect(interventions[-2..-1].pluck(:schedule_at).uniq).to match_array([nil])
    end
  end
end
