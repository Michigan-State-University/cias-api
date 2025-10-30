# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionGroup::Initial, type: :model do
  subject(:question_group_initial) { build(:question_group_initial) }

  describe 'associations' do
    it { should belong_to(:session) }
    it { should have_one(:question_initial).class_name('Question::SmsInformation') }
  end

  describe 'validations' do
    it { should be_valid }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:position) }
  end

  describe 'attributes' do
    it 'has default position of 0' do
      expect(subject.position).to eq 0
    end

    it 'has readonly position attribute' do
      expect(subject.class.readonly_attributes).to include('position')
    end

    it 'has default title from I18n' do
      expect(subject.title).to eq I18n.t('question_group.initial.title')
    end
  end

  describe 'SMS schedule validation' do
    let(:sms_session) { create(:sms_session) }
    let(:question_group_initial) { build(:question_group_initial, session: sms_session) }

    context 'with valid sms_schedule' do
      let(:valid_schedule) do
        {
          period: 'weekly',
          start_from_first_question: true,
          questions_per_day: 2,
          number_of_repetitions: 3,
          overwrite_user_time_settings: false,
          day_of_period: %w[1 3],
          time: {
            exact: '9:00 AM'
          }
        }
      end

      it 'accepts valid schedule with number_of_repetitions' do
        question_group_initial.sms_schedule = valid_schedule
        expect(question_group_initial).to be_valid
      end
    end

    context 'with invalid sms_schedule' do
      let(:invalid_schedule) do
        {
          period: 'weekly',
          questions_per_day: 'invalid', # should be integer
          day_of_period: ['1']
        }
      end

      it 'rejects invalid schedule' do
        question_group_initial.sms_schedule = invalid_schedule
        expect(question_group_initial).not_to be_valid
        expect(question_group_initial.errors[:sms_schedule]).to be_present
      end
    end

    context 'when session is not SMS type' do
      let(:regular_session) { create(:session) }
      let(:question_group_initial) { build(:question_group_initial, session: regular_session) }

      it 'does not validate sms_schedule for non-SMS sessions' do
        question_group_initial.sms_schedule = { invalid: 'data' }
        expect(question_group_initial).to be_valid
      end
    end
  end

  describe '#finish?' do
    it 'returns false' do
      expect(subject.finish?).to be false
    end
  end

  describe 'inheritance' do
    it 'inherits from QuestionGroup' do
      expect(described_class.superclass).to eq QuestionGroup
    end
  end

  describe 'default scope ordering' do
    let(:session) { create(:session) }
    let!(:initial_group) { create(:question_group_initial, session: session) }
    let!(:regular_group) { create(:question_group_plain, session: session) }

    it 'orders by position' do
      groups = session.question_groups.reload
      expect(groups.first).to eq initial_group # position 0
      expect(groups.second).to eq regular_group # position 1
    end
  end

  describe '#set_default_sms_schedule' do
    context 'when creating a new QuestionGroup::Initial for SMS session' do
      let(:sms_session) { create(:sms_session) }

      context 'when sms_schedule is not present' do
        it 'sets default sms_schedule with messages_after_limit' do
          question_group = described_class.new(session: sms_session)

          expect(question_group.sms_schedule).to eq({
                                                      'time' => {},
                                                      'day_of_period' => [],
                                                      'questions_per_day' => 1,
                                                      'messages_after_limit' => 7
                                                    })
        end

        it 'includes messages_after_limit field in default schedule' do
          question_group = described_class.new(session: sms_session)

          expect(question_group.sms_schedule['messages_after_limit']).to eq(7)
        end
      end

      context 'when sms_schedule is already present' do
        it 'does not override existing sms_schedule' do
          existing_schedule = {
            'time' => { 'exact' => '10:00 AM' },
            'day_of_period' => %w[1 3],
            'questions_per_day' => 2,
            'messages_after_limit' => 5
          }

          question_group = described_class.new(
            session: sms_session,
            sms_schedule: existing_schedule
          )

          expect(question_group.sms_schedule).to eq(existing_schedule)
        end
      end
    end
  end

  describe 'messages_after_limit validation' do
    let(:sms_session) { create(:sms_session) }
    let(:question_group_initial) { build(:question_group_initial, session: sms_session) }

    context 'with valid messages_after_limit values' do
      it 'accepts integer values' do
        question_group_initial.sms_schedule = {
          period: 'weekly',
          questions_per_day: 1,
          messages_after_limit: 10,
          day_of_period: ['1'],
          time: { exact: '8:00 AM' }
        }

        expect(question_group_initial).to be_valid
      end

      it 'accepts null values' do
        question_group_initial.sms_schedule = {
          period: 'weekly',
          questions_per_day: 1,
          messages_after_limit: nil,
          day_of_period: ['1'],
          time: { exact: '8:00 AM' }
        }

        expect(question_group_initial).to be_valid
      end

      it 'accepts zero as valid integer' do
        question_group_initial.sms_schedule = {
          period: 'weekly',
          questions_per_day: 1,
          messages_after_limit: 0,
          day_of_period: ['1'],
          time: { exact: '8:00 AM' }
        }

        expect(question_group_initial).to be_valid
      end
    end

    context 'with invalid messages_after_limit values' do
      it 'rejects string values' do
        question_group_initial.sms_schedule = {
          period: 'weekly',
          questions_per_day: 1,
          messages_after_limit: 'invalid',
          day_of_period: ['1'],
          time: { exact: '8:00 AM' }
        }

        expect(question_group_initial).not_to be_valid
        expect(question_group_initial.errors[:sms_schedule]).to be_present
      end

      it 'rejects boolean values' do
        question_group_initial.sms_schedule = {
          period: 'weekly',
          questions_per_day: 1,
          messages_after_limit: true,
          day_of_period: ['1'],
          time: { exact: '8:00 AM' }
        }

        expect(question_group_initial).not_to be_valid
        expect(question_group_initial.errors[:sms_schedule]).to be_present
      end

      it 'rejects float values' do
        question_group_initial.sms_schedule = {
          period: 'weekly',
          questions_per_day: 1,
          messages_after_limit: 7.5,
          day_of_period: ['1'],
          time: { exact: '8:00 AM' }
        }

        expect(question_group_initial).not_to be_valid
        expect(question_group_initial.errors[:sms_schedule]).to be_present
      end
    end
  end
end
