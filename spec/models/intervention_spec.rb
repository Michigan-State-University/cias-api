# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  describe 'Intervention' do
    subject { create(:intervention) }

    it { should belong_to(:problem) }
    it { should have_many(:question_groups) }
    it { should have_many(:questions) }
    it { should be_valid }

    describe '#create_default_question_group' do
      let(:new_intervention)   { build(:intervention) }
      let(:new_question_group) { new_intervention.question_groups.first }

      it 'creates new default question group' do
        expect { new_intervention.save! }.to change(QuestionGroup, :count).by(1)

        expect(new_question_group.title).to eq 'Default Screen Group'
        expect(new_question_group.position).to eq 0
      end
    end
  end

  context 'calc schedule' do
    context 'expect schedule_at when exact_date' do
      subject { create(:intervention, :exact_date) }

      it { should be_valid }
    end

    context 'expect schedule_at when days_after' do
      let(:problem) { create(:problem, created_at: 6.days.ago) }
      let(:intervention_1) { create(:intervention, problem_id: problem.id, position: 1,  created_at: 4.days.ago) }
      let(:intervention_2) { create(:intervention, problem_id: problem.id, position: 2, schedule: 'days_after', schedule_payload: 7, created_at: 2.days.ago) }

      it 'proper date' do
        intervention_1
        intervention_2
        problem.broadcast

        expect(intervention_2.reload.schedule_at).to eq(Date.current + 7)
      end
    end
  end
end
