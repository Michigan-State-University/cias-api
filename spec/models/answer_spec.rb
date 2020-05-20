# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Answer, type: :model do
  describe 'Answer::AnalogueScale' do
    describe 'expected behaviour' do
      subject { create(:answer_analogue_scale) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_analogue_scale, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::BarGraph' do
    describe 'expected behaviour' do
      subject(:answer_bar_graph) { create(:answer_bar_graph) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_bar_graph, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Blank' do
    describe 'expected behaviour' do
      subject { create(:answer_blank) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_blank, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Feedback' do
    describe 'expected behaviour' do
      subject { create(:answer_feedback) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_feedback, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::FollowUpContact' do
    describe 'expected behaviour' do
      subject { create(:answer_follow_up_contact) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_follow_up_contact, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Grid' do
    describe 'expected behaviour' do
      subject { create(:answer_grid) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_grid, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Multiple' do
    describe 'expected behaviour' do
      subject { create(:answer_multiple) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_multiple, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Name' do
    describe 'expected behaviour' do
      subject { create(:answer_name) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_name, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Number' do
    describe 'expected behaviour' do
      subject { create(:answer_number) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_number, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Single' do
    describe 'expected behaviour' do
      subject { create(:answer_single) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_single, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::TextBox' do
    describe 'expected behaviour' do
      subject { create(:answer_text_box) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_text_box, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Url' do
    describe 'expected behaviour' do
      subject { create(:answer_url) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_url, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Video' do
    describe 'expected behaviour' do
      subject { create(:answer_video) }

      it { should belong_to(:question) }
      it { should belong_to(:user).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_video, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end
end
