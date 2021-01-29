# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'Session' do
    subject { create(:session) }

    it { should belong_to(:intervention) }
    it { should have_many(:question_groups) }
    it { should have_many(:questions) }
    it { should be_valid }

    describe '#create with question groups' do
      let(:new_session) { build(:session) }

      it 'creates new default question group' do
        expect { new_session.save! }.to change(QuestionGroup, :count).by(1)
        expect(new_session.reload.question_group_plains.model_name.name).to eq 'QuestionGroup::Plain'
        expect(new_session.reload.question_group_finish.model_name.name).to eq 'QuestionGroup::Finish'
        expect(new_session.reload.question_groups.size).to eq 1
      end
    end
  end
end
