# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserIntervention, type: :model do
  context 'UserIntervention' do
    subject { create(:intervention) }

    it { should belong_to(:problem) }
    it { should have_many(:questions) }
    it { should be_valid }
  end

  context 'proper alter_schedule result' do
    let(:problem) { create(:problem) }
    let(:user) { create(:user, :participant) }
    let(:interventions) do
      interventions = create_list(:intervention, 3, problem_id: problem.id, schedule: 'days_after_fill', schedule_payload: 7)
      first_inter = interventions.first
      first_inter.update(schedule: nil, schedule_payload: nil)
      interventions
    end
    let(:user_intervention_1) { create(:user_intervention, intervention_id: interventions.first.id, user_id: user.id) }
    let(:user_intervention_2) { create(:user_intervention, intervention_id: interventions.second.id, user_id: user.id) }

    it 'calc date for next intervention properly' do
      interventions
      user_intervention_1
      user_intervention_2
      user_intervention_1.update(submitted_at: Date.current)
      user_intervention_2.reload

      expect(user_intervention_2.schedule_at).to eq(Date.current + 7)
    end
  end
end
