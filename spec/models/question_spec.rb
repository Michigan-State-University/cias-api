# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Question, type: :model do
  describe 'Question::Slider' do
    subject(:question_slider) { build(:question_slider) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::BarGraph' do
    subject(:question_bar_graph) { build(:question_bar_graph) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Feedback' do
    subject(:question_feedback) { build(:question_feedback) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Finish' do
    subject(:question_finish) { build(:question_finish) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::FollowUpContact' do
    subject(:question_follow_up_contact) { build(:question_follow_up_contact) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Grid' do
    subject(:question_grid) { build(:question_grid) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Information' do
    subject(:question_information) { build(:question_information) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Multiple' do
    subject(:question_multiple) { build(:question_multiple) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_multiple, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::Number' do
    subject(:question_number) { build(:question_number) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Single' do
    describe 'expected behaviour' do
      subject(:question_single) { build(:question_single) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_single, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::FreeResponse' do
    describe 'expected behaviour' do
      subject(:question_free_response) { build(:question_free_response) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_free_response, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::Date' do
    describe 'expected behaviour' do
      subject(:question_date) { build(:question_date) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_date, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::ExternalLink' do
    subject(:question_external_link) { build(:question_external_link) }

    it { should belong_to(:question_group) }
    it { should be_valid }
  end

  describe 'Question::Phone' do
    describe 'expected behaviour' do
      subject(:question_phone) { build(:question_phone) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_phone, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::Currency' do
    describe 'expected behaviour' do
      subject(:question_currency) { build(:question_phone) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_currency, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::Name' do
    describe 'expected behaviour' do
      subject(:question_name) { build(:question_name) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_name, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'Question::ParticipantReport' do
    describe 'expected behaviour' do
      subject(:question_participant_report) { build(:question_participant_report) }

      it { should belong_to(:question_group) }
      it { should be_valid }
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_participant_report, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end

  describe 'callbacks' do
    context 'after_create' do
      context 'when question has type Question::Finish' do
        let(:question_finish) { create(:question_finish) }

        it 'creates default block' do
          expect(question_finish['narrator']['blocks'].size).to eq(1)
        end
      end

      context 'when question has different type' do
        let(:question_single) { create(:question_single) }

        it 'does not create default block' do
          expect(question_single['narrator']['blocks'].size).to eq(0)
        end
      end
    end
  end
end
