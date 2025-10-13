# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  subject(:message) { build(:message) }

  describe 'validations' do
    it { should validate_presence_of(:phone) }
    it { should validate_presence_of(:body) }
    it { should be_valid }
  end

  describe 'associations' do
    it { should belong_to(:question).optional }

    context 'when question is present' do
      let(:question) { create(:question_sms_information) }
      let(:message) { create(:message, question: question) }

      it 'associates with question' do
        expect(message.question).to eq(question)
      end

      it 'allows retrieval of question details' do
        expect(message.question.type).to eq('Question::SmsInformation')
      end
    end

    context 'when question is nil' do
      let(:message) { create(:message, question: nil) }

      it 'allows question to be nil' do
        expect(message.question).to be_nil
        expect(message).to be_valid
      end
    end
  end

  describe 'encrypted attributes' do
    it 'encrypts phone number' do
      expect(described_class.encrypted_attributes).to include(:phone)
    end

    it 'stores and retrieves encrypted phone correctly' do
      phone_number = '+1234567890'
      message = create(:message, phone: phone_number)

      expect(message.phone).to eq(phone_number)
      expect(message.reload.phone).to eq(phone_number)
    end
  end

  describe 'paper_trail' do
    it 'has paper trail enabled' do
      expect(described_class.paper_trail.enabled?).to be true
    end

    it 'skips phone field in versioning' do
      expect(described_class.paper_trail_options[:skip]).to include(:phone)
    end

    it 'tracks changes except for phone' do
      message = create(:message, body: 'Original message')

      expect do
        message.update(body: 'Updated message')
      end.to change { message.versions.count }.by(1)
    end
  end

  describe 'question association for SMS campaigns' do
    let(:intervention) { create(:intervention) }
    let(:session) { create(:sms_session, intervention: intervention) }
    let(:question_group) { create(:question_group_initial, session: session) }
    let(:question) { create(:question_sms_information, question_group: question_group) }

    context 'when message is associated with a question' do
      let(:message) { create(:message, question: question, body: 'Test SMS message') }

      it 'can retrieve the question group through question' do
        expect(message.question.question_group).to eq(question_group)
      end

      it 'can retrieve the session through question group' do
        expect(message.question.question_group.session).to eq(session)
      end

      it 'can retrieve the intervention through session' do
        expect(message.question.question_group.session.intervention).to eq(intervention)
      end
    end

    context 'when filtering messages by question' do
      let(:question1) { create(:question_sms_information, question_group: question_group) }
      let(:question2) { create(:question_sms_information, question_group: question_group) }
      let!(:message1) { create(:message, question: question1) }
      let!(:message2) { create(:message, question: question2) }
      let!(:message_without_question) { create(:message, question: nil) }

      it 'can filter messages by specific question' do
        messages_for_question1 = described_class.where(question: question1)
        expect(messages_for_question1).to contain_exactly(message1)
      end

      it 'can filter messages by question group' do
        question_ids = question_group.questions.pluck(:id)
        messages_for_group = described_class.where(question_id: question_ids)
        expect(messages_for_group).to contain_exactly(message1, message2)
      end

      it 'can count distinct questions with messages' do
        distinct_question_count = described_class.where(question_id: [question1.id, question2.id])
                                        .distinct
                                        .count(:question_id)
        expect(distinct_question_count).to eq(2)
      end
    end

    context 'when tracking messages for repetition limits' do
      let(:user_session) { create(:sms_user_session, session: session) }
      let(:question1) { create(:question_sms_information, question_group: question_group) }
      let(:question2) { create(:question_sms_information, question_group: question_group) }

      let!(:old_message) do
        create(:message, question: question1, created_at: 3.days.ago)
      end
      let!(:recent_message1) do
        create(:message, question: question1, created_at: 1.day.ago)
      end
      let!(:recent_message2) do
        create(:message, question: question2, created_at: 12.hours.ago)
      end
      let!(:duplicate_recent_message) do
        create(:message, question: question1, created_at: 6.hours.ago) # Same question as recent_message1
      end

      it 'can count messages sent after a specific timestamp' do
        messages_after_2_days_ago = described_class.where(
          question_id: session.questions.select(:id),
          created_at: 2.days.ago..Time.current
        )
        expect(messages_after_2_days_ago.count).to eq(3)
      end

      it 'can count distinct questions with messages after timestamp' do
        distinct_questions_count = described_class.where(
          question_id: session.questions.select(:id),
          created_at: 2.days.ago..Time.current
        ).distinct.count(:question_id)

        expect(distinct_questions_count).to eq(2) # question1 and question2
      end

      it 'handles foreign key constraint properly' do
        expect do
          create(:message, question: question1)
        end.not_to raise_error
      end
    end
  end

  describe 'factory' do
    it 'creates valid message with factory' do
      message = create(:message)
      expect(message).to be_valid
      expect(message.phone).to be_present
      expect(message.body).to be_present
    end

    it 'creates valid message with question using factory' do
      question = create(:question_sms_information)
      message = create(:message, question: question)

      expect(message).to be_valid
      expect(message.question).to eq(question)
    end
  end
end
