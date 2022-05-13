# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/clone_multiple', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group) { create(:question_group_plain, title: 'Question Group Title', position: 1, session: session) }
  let!(:question_group2) do
    create(:question_group_plain, title: 'Question Group 2 Title', position: 2, session: session)
  end

  let!(:questions) { create_list(:question_single, 3, title: 'Question Id Title', question_group: question_group) }
  let!(:questions2) do
    create_list(:question_slider, 3, title: 'Question 2 Id Title', question_group: question_group2)
  end

  let(:question_ids) { questions.pluck(:id) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      ids: question_ids
    }
  end
  let(:request) { post v1_session_clone_multiple_questions_path(session.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_session_clone_multiple_questions_path(session.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user clones questions' do
    context 'when params are valid' do
      context 'questions are from one question_group' do
        before { request }

        it { expect(response).to have_http_status(:created) }

        it 'returns proper cloned question attributes' do
          expect(json_response['data'][0]['attributes']['title']).to eq('Question Id Title')
          expect(json_response['data'][1]['attributes']['title']).to eq('Question Id Title')
          expect(json_response['data'][2]['attributes']['title']).to eq('Question Id Title')
        end

        it 'returned cloned questions have proper position' do
          expect(json_response['data'][0]['attributes']['position']).to eq(questions.last.position + 1)
          expect(json_response['data'][1]['attributes']['position']).to eq(questions.last.position + 2)
          expect(json_response['data'][2]['attributes']['position']).to eq(questions.last.position + 3)
        end

        it 'last element has proper title' do
          expect(question_group.reload.questions.last.title).to eq('Question Id Title')
        end

        it 'last element has proper position' do
          expect(question_group.reload.questions.last.position).to eq(questions.last.position + 3)
        end

        it 'returns proper number of questions from question_group' do
          expect(question_group.reload.questions.size).to eq(6)
        end

        it 'returns proper number of cloned questions' do
          expect(json_response['data'].size).to eq(question_ids.size)
        end

        it 'cloned questions belong to question_group' do
          expect(json_response['data'][0]['attributes']['question_group_id']).to eq(question_group.id)
          expect(json_response['data'][1]['attributes']['question_group_id']).to eq(question_group.id)
          expect(json_response['data'][2]['attributes']['question_group_id']).to eq(question_group.id)
        end
      end

      context 'questions are from different question_groups' do
        let(:question_ids) { [questions.last.id, questions2.last.id] }

        before { request }

        it { expect(response).to have_http_status(:created) }

        it 'returns proper cloned question attributes' do
          result = [json_response['data'][0]['attributes']['title'], json_response['data'][1]['attributes']['title']]
          expect(result).to include('Question Id Title', 'Question 2 Id Title')
        end

        it 'returned cloned questions have proper position' do
          expect(json_response['data'][0]['attributes']['position']).to eq(1)
          expect(json_response['data'][1]['attributes']['position']).to eq(2)
        end

        it 'first and last element has proper title' do
          expect(session.reload.question_groups.last(2).first.questions.pluck(:title)).to include('Question Id Title', 'Question 2 Id Title')
        end

        it 'first element has proper position' do
          expect(session.reload.question_groups.last(2).first.questions.first.position).to eq(1)
        end

        it 'last element has proper position' do
          expect(session.reload.question_groups.last(2).first.questions.last.position).to eq(2)
        end

        it 'returns proper number of questions from question_group' do
          expect(session.reload.question_groups.last(2).first.questions.size).to eq(question_ids.size)
        end

        it 'returns proper number of cloned questions' do
          expect(json_response['data'].size).to eq(question_ids.size)
        end

        it 'cloned questions belong to  new question_group' do
          expect(json_response['data'][0]['attributes']['question_group_id']).to eq(session.reload.question_groups.last(2).first.id)
          expect(json_response['data'][1]['attributes']['question_group_id']).to eq(session.reload.question_groups.last(2).first.id)
        end
      end
    end

    context 'when params are invalid' do
      context 'one of question ids is invalid' do
        let(:params) do
          {
            ids: questions.pluck(:id) << 'invalid'
          }
        end

        before { request }

        it { expect(response).to have_http_status(:not_found) }
      end

      context 'ids are empty' do
        let(:params) { { ids: [] } }

        before { request }

        it { expect(response).to have_http_status(:not_found) }
      end

      context 'params doesn\'t exist' do
        let(:params) { {} }

        before { request }

        it { expect(response).to have_http_status(:not_found) }
      end
    end
  end
end
