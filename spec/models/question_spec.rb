# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Question, type: :model do
  describe 'Question::AnalogueScale' do
    subject(:question_analogue_scale) { build(:question_analogue_scale) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::BarGraph' do
    subject(:question_bar_graph) { build(:question_bar_graph) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Blank' do
    subject(:question_blank) { build(:question_blank) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Feedback' do
    subject(:question_feedback) { build(:question_feedback) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::FollowUpContact' do
    subject(:question_follow_up_contact) { build(:question_follow_up_contact) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Grid' do
    subject(:question_grid) { build(:question_grid) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Multiple' do
    subject(:question_multiple) { build(:question_multiple) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Name' do
    subject(:question_name) { build(:question_name) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Number' do
    subject(:question_number) { build(:question_number) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Single' do
    subject(:question_single) { build(:question_single) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::TextBox' do
    subject(:question_text_box) { build(:question_text_box) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Url' do
    subject(:question_url) { build(:question_url) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end

  describe 'Question::Video' do
    subject(:question_video) { build(:question_video) }

    it { should belong_to(:intervention) }
    it { should be_valid }
  end
end
