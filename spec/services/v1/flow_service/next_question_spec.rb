# frozen_string_literal: true

RSpec.describe V1::FlowService::NextQuestion do
  subject { described_class.new(user_session).call(nil) }

  let(:predefined_user) { create(:user, :predefined_participant) }
  let(:intervention) { create(:intervention, status: :published) }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let(:user_int) { create(:user_intervention, intervention: intervention, user: predefined_user) }
  let!(:user_session) { create(:user_session, user_id: predefined_user.id, session_id: session.id, user_intervention: user_int) }
  let!(:question_group) { create(:question_group, session: session, position: 1) }
  let!(:question) { create(:question_participant_report, question_group: question_group, position: 1) }

  it 'first and last question is participant report screen' do
    expect(subject.type).to eql('Question::Finish')
  end

  context 'question group has next question' do
    let!(:single_question) { create(:question_single, question_group: question_group, position: 2) }

    it 'returns FinishQuestion' do
      expect(subject.id).to eql(single_question.id)
    end
  end

  context 'user has some answers' do
    let!(:question) { create(:question_single, question_group: question_group, position: 1) }
    let!(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id) }
    let!(:second_question) { create(:question_participant_report, question_group: question_group, position: 2) }

    it 'first and last question is participant report screen' do
      expect(subject.type).to eql('Question::Finish')
    end

    context 'single question after participnat report screen' do
      let!(:single_question) { create(:question_single, question_group: question_group, position: 3) }

      it 'returns next single question' do
        expect(subject.id).to eql(single_question.id)
      end
    end

    context 'question from next question group' do
      let!(:second_question_group) { create(:question_group, session: session, position: 2) }
      let!(:first_question_in_next_group) { create(:question_single, question_group: second_question_group) }

      it 'returns the first question from the next question group' do
        expect(subject.id).to eql(first_question_in_next_group.id)
      end
    end
  end

  context 'predefined participant with participant report before finish screen' do
    let!(:question) { create(:question_single, question_group: question_group, position: 1) }
    let!(:answer) { create(:answer_single, question_id: question.id, user_session_id: user_session.id) }
    let!(:participant_report) { create(:question_participant_report, question_group: question_group, position: 2) }
    let!(:finish_question) { create(:question_finish, question_group: question_group, position: 3) }

    context 'when predefined participant encounters participant report before finish screen' do
      it 'skips participant report, goes to finish screen, and marks session as finished' do
        expect(user_session.finished_at).to be_nil

        result = subject
        expect(result.type).to eql('Question::Finish')
        expect(user_session.reload.finished_at).to be_present
      end
    end

    context 'when finish question is in next question group' do
      let!(:finish_question_group) { create(:question_group, session: session, position: 2) }
      let!(:finish_question) { create(:question_finish, question_group: finish_question_group, position: 1) }

      it 'skips participant report, goes to finish screen in next group, and marks session as finished' do
        expect(user_session.finished_at).to be_nil

        result = subject
        expect(result.type).to eql('Question::Finish')
        expect(user_session.reload.finished_at).to be_present
      end
    end
  end
end
