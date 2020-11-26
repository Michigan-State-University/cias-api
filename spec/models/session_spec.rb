# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'Session' do
    subject { create(:session) }

    it { should belong_to(:problem) }
    it { should have_many(:question_groups) }
    it { should have_many(:questions) }
    it { should be_valid }

    describe '#create with question groups' do
      let(:new_session) { build(:session) }

      it 'creates new default question group' do
        expect { new_session.save! }.to change(QuestionGroup, :count).by(2)
        expect(new_session.reload.question_group_plains.model_name.name).to eq 'QuestionGroup::Plain'
        expect(new_session.reload.question_group_finish.model_name.name).to eq 'QuestionGroup::Finish'
        expect(new_session.reload.question_groups.size).to eq 2
      end
    end
  end

  context 'calc schedule' do
    context 'expect schedule_at when exact_date' do
      subject { create(:session, :exact_date) }

      it { should be_valid }
    end

    context 'expect schedule_at when days_after' do
      let(:problem) { create(:problem, created_at: 6.days.ago) }
      let(:session_1) { create(:session, problem_id: problem.id, position: 1,  created_at: 4.days.ago) }
      let(:session_2) { create(:session, problem_id: problem.id, position: 2, schedule: 'days_after', schedule_payload: 7, created_at: 2.days.ago) }

      it 'proper date' do
        session_1
        session_2
        problem.broadcast

        expect(session_2.reload.schedule_at).to eq(Date.current + 7)
      end
    end
  end
end
