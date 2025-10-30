# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionGroup, type: :model do
  describe 'QuestionGroup::Plain' do
    subject(:question_group_plain) { build(:question_group_plain) }

    it { should belong_to(:session) }
    it { should be_valid }

    it 'responds to message finish? and should be false' do
      expect(subject.finish?).to be false
    end
  end

  describe 'QuestionGroup::Initial' do
    describe 'model definition' do
      subject(:question_group_initial) { build(:question_group_initial) }

      it { should belong_to(:session) }
      it { should be_valid }

      it 'responds to message finish? and should be false' do
        expect(subject.finish?).to be false
      end

      it 'has default position of 0' do
        expect(subject.position).to eq 0
      end

      it 'has readonly position attribute' do
        expect(subject.class.readonly_attributes).to include('position')
      end
    end
  end

  describe 'QuestionGroup::Finish' do
    describe 'model definition' do
      subject(:question_group_finish) { build(:question_group_finish) }

      it { should belong_to(:session) }
      it { should be_valid }

      it 'responds to message finish? and should be true' do
        expect(subject.finish?).to be true
      end
    end
  end
end
