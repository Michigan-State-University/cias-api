# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSession::Sms, type: :model do
  subject(:sms_user_session) { create(:sms_user_session) }

  describe 'attributes' do
    it 'has number_of_repetitions attribute' do
      expect(sms_user_session).to respond_to(:number_of_repetitions)
      expect(sms_user_session).to respond_to(:number_of_repetitions=)
    end

    it 'has max_repetitions_reached_at attribute' do
      expect(sms_user_session).to respond_to(:max_repetitions_reached_at)
      expect(sms_user_session).to respond_to(:max_repetitions_reached_at=)
    end

    it 'allows number_of_repetitions to be nil' do
      sms_user_session.number_of_repetitions = nil
      expect(sms_user_session).to be_valid
    end

    it 'allows number_of_repetitions to be zero' do
      sms_user_session.number_of_repetitions = 0
      expect(sms_user_session).to be_valid
    end

    it 'allows number_of_repetitions to be a positive integer' do
      sms_user_session.number_of_repetitions = 5
      expect(sms_user_session).to be_valid
      expect(sms_user_session.number_of_repetitions).to eq(5)
    end

    it 'allows max_repetitions_reached_at to be nil' do
      sms_user_session.max_repetitions_reached_at = nil
      expect(sms_user_session).to be_valid
    end

    it 'allows max_repetitions_reached_at to be a datetime' do
      timestamp = DateTime.current
      sms_user_session.max_repetitions_reached_at = timestamp
      expect(sms_user_session).to be_valid
      expect(sms_user_session.max_repetitions_reached_at).to eq(timestamp)
    end
  end

  describe 'inheritance' do
    it 'inherits from UserSession' do
      expect(described_class.superclass).to eq(UserSession)
    end
  end

  describe 'delegations' do
    let(:session) { create(:sms_session) }
    let(:sms_user_session) { create(:sms_user_session, session: session) }

    it 'delegates first_question to session' do
      expect(sms_user_session.session).to receive(:first_question)
      sms_user_session.first_question
    end

    it 'delegates autofinish_enabled to session' do
      expect(sms_user_session.session).to receive(:autofinish_enabled)
      sms_user_session.autofinish_enabled
    end

    it 'delegates autofinish_delay to session' do
      expect(sms_user_session.session).to receive(:autofinish_delay)
      sms_user_session.autofinish_delay
    end

    it 'delegates questions to session' do
      expect(sms_user_session.session).to receive(:questions)
      sms_user_session.questions
    end
  end

  describe '#last_answer' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:session) { create(:sms_session) }
    let(:sms_user_session) { create(:sms_user_session, user: user, session: session) }
    let(:question1) { create(:question_sms, question_group: sms_user_session.session.question_groups.first) }
    let(:question2) { create(:question_sms, question_group: sms_user_session.session.question_groups.first) }

    let!(:old_answer) do
      create(:answer_sms, user_session: sms_user_session, question: question1, updated_at: 2.days.ago)
    end
    let!(:recent_answer) do
      create(:answer_sms, user_session: sms_user_session, question: question2, updated_at: 1.day.ago)
    end

    it 'returns the most recently updated confirmed answer' do
      expect(sms_user_session.last_answer).to eq(recent_answer)
    end

    context 'when there are unconfirmed answers' do
      let!(:unconfirmed_answer) do
        create(:answer_sms, user_session: sms_user_session, question: question1, updated_at: DateTime.current, draft: true)
      end

      it 'only considers confirmed answers' do
        expect(sms_user_session.last_answer).to eq(recent_answer)
      end
    end
  end

  describe '#find_current_question' do
    let(:intervention) { create(:intervention) }
    let(:session) { create(:sms_session, intervention: intervention) }
    let(:question_group) { create(:question_group, session: session) }
    let(:user) { create(:user, :confirmed, :participant) }
    let(:sms_user_session) { create(:sms_user_session, user: user, session: session) }

    it 'finds current question based on answered questions' do
      expect(sms_user_session).to respond_to(:find_current_question)
    end
  end

  describe '#on_answer' do
    it 'responds to on_answer method' do
      expect(sms_user_session).to respond_to(:on_answer)
    end

    it 'does not raise error when called' do
      expect { sms_user_session.on_answer }.not_to raise_error
    end
  end

  describe '#finish' do
    context 'when not already finished' do
      it 'sets finished_at timestamp' do
        expect(sms_user_session.finished_at).to be_nil
        sms_user_session.finish
        expect(sms_user_session.finished_at).to be_present
        expect(sms_user_session.finished_at).to be_within(1.second).of(DateTime.current)
      end
    end

    context 'when already finished' do
      before do
        sms_user_session.update(finished_at: 1.day.ago)
      end

      it 'does not update finished_at' do
        original_finished_at = sms_user_session.finished_at
        sms_user_session.finish
        expect(sms_user_session.finished_at).to eq(original_finished_at)
      end
    end
  end
end
