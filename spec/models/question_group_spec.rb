# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionGroup, type: :model do
  describe 'QuestionGroup::Default' do
    subject(:question_group_default) { build(:question_group_default) }

    it { should belong_to(:session) }
    it { should be_valid }

    it 'responds to message default? and should be true' do
      expect(subject.default?).to be true
    end
  end

  describe 'QuestionGroup::Plain' do
    subject(:question_group_plain) { build(:question_group_plain) }

    it { should belong_to(:session) }
    it { should be_valid }

    it 'responds to message default? and should be false' do
      expect(subject.default?).to be false
    end
  end

  describe 'QuestionGroup::Finish' do
    describe 'model definition' do
      subject(:question_group_finish) { build(:question_group_finish) }

      it { should belong_to(:session) }
      it { should be_valid }
    end
  end
end
