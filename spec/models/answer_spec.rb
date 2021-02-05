# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Answer, type: :model do
  describe 'Answer::Slider' do
    describe 'expected behaviour' do
      subject { create(:answer_slider) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_slider, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::BarGraph' do
    describe 'expected behaviour' do
      subject(:answer_bar_graph) { create(:answer_bar_graph) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_bar_graph, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Feedback' do
    describe 'expected behaviour' do
      subject { create(:answer_feedback) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
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
      it { should belong_to(:user_session).optional(true) }
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
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_grid, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Information' do
    describe 'expected behaviour' do
      subject { create(:answer_information) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_information, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end

  describe 'Answer::Multiple' do
    describe 'expected behaviour' do
      subject { create(:answer_multiple) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_multiple, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end

    describe 'does not fail when body is empty' do
      let(:with_empty) { build(:answer_multiple, :body_data_empty) }

      it { expect(with_empty.save).to eq true }
    end
  end

  describe 'Answer::Number' do
    describe 'expected behaviour' do
      subject { create(:answer_number) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
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
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_single, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end

    describe 'does not fail when body is empty' do
      let(:with_empty) { build(:answer_single, :body_data_empty) }

      it { expect(with_empty.save).to eq true }
    end
  end

  describe 'Answer::FreeResponse' do
    describe 'expected behaviour' do
      subject { create(:answer_free_response) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_free_response, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end

    describe 'does not fail when body is empty' do
      let(:with_empty) { build(:answer_free_response, :body_data_empty) }

      it { expect(with_empty.save).to eq true }
    end
  end

  describe 'Answer::Date' do
    describe 'expected behaviour' do
      subject { create(:answer_date) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_date, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end

    describe 'does not fail when body is empty' do
      let(:with_empty) { build(:answer_date, :body_data_empty) }

      it { expect(with_empty.save).to eq true }
    end
  end

  describe 'Answer::ExternalLink' do
    describe 'expected behaviour' do
      subject { create(:answer_external_link) }

      it { should belong_to(:question) }
      it { should belong_to(:user_session).optional(true) }
      it { should be_valid }
    end

    describe 'mismatch type question and answer' do
      let(:wrong_type) { build(:answer_external_link, :wrong_type) }

      it { expect(wrong_type.save).to eq false }
    end
  end
end
