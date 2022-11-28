# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sessions/:session_id/delete_questions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
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

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
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
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
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

  context 'delete tlfb questions' do
    context 'when user wants to delete only part of tlfb group' do
      let!(:tlfb_group) { create(:tlfb_group, session: session) }
      let!(:params) do
        {
          ids: [tlfb_group.questions.first.id]
        }
      end

      it 'return correct status' do
        request
        expect(response).to have_http_status(:bad_request)
      end

      it 'did\'t delete questions' do
        request
        expect(question_group.reload.questions.count).to be(3)
      end
    end

    context 'when user wants delete all group' do
      let!(:tlfb_group) { create(:tlfb_group, session: session) }
      let!(:params) do
        {
          ids: tlfb_group.questions.pluck(:id)
        }
      end

      it 'return correct status' do
        request
        expect(response).to have_http_status(:no_content)
      end

      it 'delete questions' do
        expect { request }.to change(Question, :count).by(-3)
      end

      it 'delete group' do
        expect { request }.to change(QuestionGroup, :count).by(-1)
      end
    end
  end

  context 'when duplicated question was moved' do
    let(:new_question_group) { create(:question_group, title: 'New Question Group', session: session) }
    let(:other_new_question_group) { create(:question_group, title: 'Other New Question Group', session: session) }
    let(:new_question) { create(:question_date, question_group: new_question_group) }
    let(:duplicate_request) { post v1_clone_question_path(id: new_question.id), headers: headers }
    let(:duplicated_question) do
      duplicate_request
      Question.find(json_response['data']['id'])
    end
    let(:move_request) { patch v1_session_move_question_path(session_id: session.id), params: move_params, headers: headers }
    let(:move_params) do
      {
        question: {
          position: [
            {
              id: duplicated_question.id,
              position: 11,
              question_group_id: other_new_question_group.id
            }
          ]
        }
      }
    end

    let(:params) { { ids: [duplicated_question.id] } }

    before { request }

    it 'returns proper http status' do
      expect(response).to have_http_status(:no_content)
    end

    it 'deletes duplicated question' do
      expect(Question.find_by(id: duplicated_question.id)).to eq(nil)
    end

    it 'do not delete the original' do
      expect(Question.find_by(id: new_question.id)).not_to eq(nil)
    end
  end
end
