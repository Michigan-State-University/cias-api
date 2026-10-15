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

    context 'when position params are malicious' do
      context 'when position contains an SQL expression' do
        let(:params) { { question: { position: [{ id: question1.id, position: '7+(SELECT 770)', question_group_id: question_group1.id }] } } }

        before { request }

        it 'does not evaluate it' do
          pending 'BUG: position is interpolated into question_bulk_update.sql.erb, so the subquery is executed (SQL injection)'
          expect(question1.reload.position).not_to eq(777)
        end
      end

      context 'when id contains a quote' do
        let(:params) { { question: { position: [{ id: "x'", position: 1, question_group_id: question_group1.id }] } } }

        before { request }

        it 'does not break the SQL statement' do
          pending 'BUG: id is interpolated into a string literal in question_bulk_update.sql.erb, a quote ends it (SQL syntax error)'
          expect(response.body).not_to include('PG::SyntaxError')
        end
      end

      context 'when question belongs to another researcher' do
        let(:other_session) { create(:session, intervention: create(:intervention, user: create(:user, :researcher))) }
        let(:other_question_group) { create(:question_group, session: other_session, position: 1) }
        let!(:other_question) { create(:question_free_response, question_group: other_question_group, position: 0) }
        let(:params) { { question: { position: [{ id: other_question.id, position: 4, question_group_id: question_group1.id }] } } }

        before { request }

        it 'does not move it into own question group' do
          pending 'BUG: QuestionsController#move updates any question by id, not only questions of the authorized session (IDOR)'
          expect(other_question.reload.question_group_id).to eq(other_question_group.id)
        end
      end
    end
  end
end
