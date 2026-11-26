# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/questions/move', type: :request do
  let(:request) { patch v1_session_move_question_path(session_id: session.id), params: params, headers: headers }

  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group1) { create(:question_group, title: 'Question Group 1 Title', session: session, position: 1) }
  let!(:question_group2) { create(:question_group, title: 'Question Group 2 Title', session: session, position: 2) }
  let!(:question1)       { create(:question_free_response, question_group: question_group1, position: 0) }
  let!(:question2)       { create(:question_free_response, question_group: question_group1, position: 1) }
  let!(:question3)       { create(:question_free_response, question_group: question_group1, position: 2) }
  let!(:question4)       { create(:question_free_response, question_group: question_group2, position: 0) }
  let!(:question5)       { create(:question_free_response, question_group: question_group2, position: 1) }
  let!(:question6)       { create(:question_free_response, question_group: question_group2, position: 2) }
  let!(:question7)       { create(:question_free_response, question_group: question_group2, position: 3) }

  let(:params) do
    {
      question: {
        position: [
          {
            id: question1.id,
            position: 11,
            question_group_id: question_group2.id
          },
          {
            id: question2.id,
            position: 22,
            question_group_id: question_group2.id
          },
          {
            id: question3.id,
            position: 33,
            question_group_id: question_group2.id
          },
          {
            id: question4.id,
            position: 0,
            question_group_id: question_group2.id
          },
          {
            id: question5.id,
            position: 1,
            question_group_id: question_group2.id
          },
          {
            id: question6.id,
            position: 2,
            question_group_id: question_group2.id
          },
          {
            id: question7.id,
            position: 3,
            question_group_id: question_group2.id
          }
        ]
      }
    }
  end

  context 'when authenticated as guest user' do
    let(:user) { create(:user, :guest) }
    let(:headers) { user.create_new_auth_token }

    it 'returns forbidden status' do
      request

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authenticated as researcher user' do
    let(:user) { create(:user, :researcher) }
    let(:headers) { user.create_new_auth_token }

    context 'when question group does not have questions' do
      before { request }

      it 'returns serialized cloned question_group' do
        expect(response).to have_http_status(:ok)
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].size).to eq 3
        expect(question1.reload.position).to eq 11
        expect(question2.reload.position).to eq 22
        expect(question3.reload.position).to eq 33
      end

      it 'changes question groups question count' do
        expect(question_group2.reload.questions_count).to eq(7)
      end
    end

    it 'moves questions to the new question group' do
      request
      expect(question1.reload.question_group_id).to eq question_group2.id
    end

    context 'when position is sent as a single object instead of an array' do
      let(:params) { { question: { position: { id: question1.id, position: 11, question_group_id: question_group2.id } } } }

      before { request }

      it { expect(response).to have_http_status(:bad_request) }

      it 'does not move the question' do
        expect(question1.reload.question_group_id).to eq question_group1.id
      end
    end

    context 'when a question of another session is in the list' do
      let(:other_group) { create(:question_group, session: create(:session, intervention: session.intervention)) }
      let(:other_question) { create(:question_free_response, question_group: other_group, position: 5) }
      let(:params) { { question: { position: [{ id: other_question.id, position: 1, question_group_id: question_group2.id }] } } }

      before { request }

      it { expect(response).to have_http_status(:not_found) }
      it { expect(other_question.reload.question_group_id).to eq other_group.id }
    end

    context 'when the target group belongs to another session' do
      let(:other_group) { create(:question_group, session: create(:session, intervention: session.intervention)) }
      let(:params) { { question: { position: [{ id: question1.id, position: 1, question_group_id: other_group.id }] } } }

      before { request }

      it { expect(response).to have_http_status(:not_found) }
      it { expect(question1.reload.question_group_id).to eq question_group1.id }
    end

    context 'when a question_group_id is not a UUID' do
      let(:params) { { question: { position: [{ id: question1.id, position: 1, question_group_id: 'abc' }] } } }

      before { request }

      it { expect(response).to have_http_status(:unprocessable_content) }
      it { expect(question1.reload.question_group_id).to eq question_group1.id }
    end

    context 'when the move leaves a group empty' do
      let!(:emptied_group) { create(:question_group_plain, session: session, position: 3) }
      let!(:emptied_question) { create(:question_free_response, question_group: emptied_group, position: 0) }
      let!(:other_session_group) { create(:question_group_plain, session: create(:session, intervention: session.intervention)) }
      let(:params) { { question: { position: [{ id: emptied_question.id, position: 9, question_group_id: question_group2.id }] } } }

      before { request }

      it 'deletes the emptied group of this session and keeps empty groups of other sessions' do
        expect(response).to have_http_status(:ok)
        expect(QuestionGroup.exists?(emptied_group.id)).to be false
        expect(QuestionGroup.exists?(other_session_group.id)).to be true
      end
    end

    it 'moves the questions in one statement, without audits or versions' do
      statements = []
      callback = ->(*, payload) { statements << payload[:sql] if payload[:sql].start_with?('UPDATE "questions"') }

      expect { ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { request } }.not_to(change do
        [Audited::Audit.where(auditable_type: %w[Question QuestionGroup]).count,
         PaperTrail::Version.where(item_type: %w[Question QuestionGroup]).count]
      end)
      expect(statements.size).to eq 1
    end

    context 'when the emptied group cannot be deleted' do
      let!(:tlfb_group) { create(:tlfb_group, session: session, position: 3) }
      let(:params) do
        rows = tlfb_group.questions.map { |question| { id: question.id, position: question.position, question_group_id: question_group2.id } }
        { question: { position: rows } }
      end

      before do
        create(:tlfb_day, question_group: tlfb_group, user_session: create(:user_session, session: session))
        request
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(tlfb_group.questions.reload.size).to eq 3 }
    end

    it 'cleans up empty groups in one DELETE limited to the session' do
      deletes = []
      callback = ->(*, payload) { deletes << payload[:sql] if payload[:sql].start_with?('DELETE FROM "question_groups"') }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { request }
      expect(deletes.size).to eq 1
      expect(deletes.first).to include('"question_groups"."session_id" =')
    end
  end
end
