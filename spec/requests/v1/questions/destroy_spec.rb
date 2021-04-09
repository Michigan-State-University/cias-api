# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sessions/:session_id/delete_questions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group) { create(:question_group, title: 'First Question Group', session: session) }
  let!(:other_question_group) { create(:question_group, title: 'Second Question Group', session: session) }
  let!(:questions) { create_list(:question_slider, 3, question_group: question_group) }
  let!(:other_questions) { create_list(:question_slider, 3, question_group: other_question_group) }
  let!(:answers) { create_list(:answer_slider, 3, question: questions.first) }
  let!(:other_answers) { create_list(:answer_slider, 3, question: other_questions.first) }
  let(:headers) { user.create_new_auth_token }
  let!(:params) do
    {
      ids: questions.pluck(:id) + other_questions.pluck(:id).without(other_questions.last.id)
    }
  end
  let(:request) { delete v1_session_delete_questions_path(session_id: session.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_session_delete_questions_path(session_id: session.id), params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is success' do
      before { request }

      it 'returns proper http status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'deletes questions' do
        expect(Question.find_by(id: questions.first.id)).to eq(nil)
      end

      it 'keeps last question' do
        expect(Question.find_by(id: other_questions.last.id)).to eq(other_questions.last)
      end

      it 'keeps second question_group' do
        expect(QuestionGroup.find_by(id: other_question_group.id)).to eq(other_question_group)
      end

      it 'deletes first question_group' do
        expect(QuestionGroup.find_by(id: question_group.id)).to eq(nil)
      end

      it 'deletes answers' do
        expect(Answer.find_by(id: answers.first.id)).to eq(nil)
      end
    end
  end

  context 'when one of ids is invalid' do
    let(:params) do
      {
        ids: [questions.first.id, 'invalid', questions.second.id]
      }
    end

    before { request }

    it { expect(response).to have_http_status(:not_found) }
    it { expect(questions.size).to be(3) }
    it { expect(questions.first).not_to be(nil) }
    it { expect(other_questions.size).to be(3) }
  end
end
