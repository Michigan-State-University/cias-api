# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/sessions/:session_id/question_groups/:id/share', type: :request do
  let(:user) { create(:user, :researcher) }
  let!(:intervention) { create(:intervention, user: user) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:question_group_plain, session: session, position: 1) }
  let!(:other_question_group) { create(:question_group_plain, session: session, position: 2) }
  let!(:question_ids) do
    create_list(:question_single, 3, :narrator_block_one, title: 'Question Id Title', question_group: question_group,
                                                          formula: { 'payload' => 'var + 4', 'patterns' => [
                                                            { 'match' => '=3', 'target' => [{ 'id' => other_session.id, type: 'Session' }] }
                                                          ] })
  end
  let!(:other_question_ids) do
    create_list(:question_free_response, 2, title: 'Other question Id Title', question_group: other_question_group)
  end

  let!(:other_intervention) { create(:intervention, user: user) }
  let!(:other_session) { create(:session, intervention: other_intervention) }
  let!(:shared_question_group) { create(:question_group_plain, session: other_session, position: 1) }
  let!(:shared_questions) do
    create_list(:question_free_response, 2, title: 'Shared question Id Title', question_group: shared_question_group)
  end
  let!(:first_question_position) { shared_questions.first.position }
  let(:request) do
    post share_v1_session_question_group_path(session_id: other_session.id, id: shared_question_group.id), params: params,
                                                                                                           headers: user.create_new_auth_token
  end

  let(:params) do
    {
      question_group: {
        question_ids: question_ids.pluck(:id),
        question_group_ids: [other_question_group.id]
      }
    }
  end

  context 'when authenticated as researcher user' do
    context 'when parameters are proper' do
      shared_examples 'cleared branching, variables and speech blocks' do
        let(:third_question) { shared_question_group.reload.questions.third }

        it 'returned questions have no branching,variables and cleared speech blocks' do
          expect(json_response['included'][2]['attributes']['narrator']['blocks']).to eq question_ids.third.narrator['blocks']
          expect(json_response['included'][2]['attributes']['formula']).not_to eq question_ids.third.formula
          expect(json_response['included'][2]['attributes']['body']['data']).to eq question_ids.third.body['data']
        end

        it 'shared_question_group questions have no branching,variables and cleared speech blocks' do
          expect(third_question.narrator['blocks']).to eq question_ids.third.narrator['blocks']
          expect(third_question.formula).not_to eq question_ids.third.formula
          expect(third_question.body['data']).to eq question_ids.third.body['data']
        end
      end

      context 'when question group ids and question ids are present' do
        before { request }

        it 'returns ok status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns serialized question_group with new questions' do
          expect(json_response['included'][0]['attributes']['title']).to eq 'Shared question Id Title'
          expect(json_response['included'][2]['attributes']['title']).to eq 'Question Id Title'
          expect(json_response['included'][6]['attributes']['title']).to eq 'Other question Id Title'
        end

        it 'shared_question_group questions have proper title' do
          expect(shared_question_group.reload.questions[0].title).to eq 'Shared question Id Title'
          expect(shared_question_group.reload.questions[2].title).to eq 'Question Id Title'
          expect(shared_question_group.reload.questions[6].title).to eq 'Other question Id Title'
        end

        it 'returns proper number of questions' do
          expect(json_response['included'].size).to eq 7
        end

        it 'shared_question_group has proper number of questions' do
          expect(shared_question_group.reload.questions.size).to eq 7
        end

        it 'shared question is copied' do
          expect(shared_question_group.reload.questions[2].id).not_to eq question_ids.first.id
        end

        it 'returns questions with proper positions' do
          expect(json_response['included'][0]['attributes']['position']).to eq first_question_position
          expect(json_response['included'][2]['attributes']['position']).to eq first_question_position + 2
          expect(json_response['included'][6]['attributes']['position']).to eq first_question_position + 6
        end

        it 'shared questions have proper positions' do
          expect(shared_question_group.reload.questions[0].position).to eq first_question_position
          expect(shared_question_group.reload.questions[2].position).to eq first_question_position + 2
          expect(shared_question_group.reload.questions[6].position).to eq first_question_position + 6
        end

        include_examples 'cleared branching, variables and speech blocks'
      end

      context 'when user clones questions from current question_group' do
        let(:request) do
          post share_v1_session_question_group_path(session_id: session.id, id: question_group.id), params: params,
                                                                                                    headers: user.create_new_auth_token
        end
        let!(:first_question_position) { question_ids.first.position }

        before { request }

        it 'returns ok status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns serialized question_group with new questions' do
          expect(json_response['included'][0]['attributes']['title']).to eq 'Question Id Title'
          expect(json_response['included'][2]['attributes']['title']).to eq 'Question Id Title'
          expect(json_response['included'][6]['attributes']['title']).to eq 'Other question Id Title'
        end

        it 'shared_question_group questions have proper title' do
          expect(question_group.reload.questions[0].title).to eq 'Question Id Title'
          expect(question_group.reload.questions[2].title).to eq 'Question Id Title'
          expect(question_group.reload.questions[6].title).to eq 'Other question Id Title'
        end

        it 'returns proper number of questions' do
          expect(json_response['included'].size).to eq 8
        end

        it 'shared_question_group has proper number of questions' do
          expect(question_group.reload.questions.size).to eq 8
        end

        it 'shared question is copied' do
          expect(question_group.reload.questions[2].id).not_to eq question_ids.first.id
        end

        it 'returns questions with proper positions' do
          expect(json_response['included'][0]['attributes']['position']).to eq first_question_position
          expect(json_response['included'][2]['attributes']['position']).to eq first_question_position + 2
          expect(json_response['included'][6]['attributes']['position']).to eq first_question_position + 6
        end

        it 'shared questions have proper positions' do
          expect(question_group.reload.questions[0].position).to eq first_question_position
          expect(question_group.reload.questions[2].position).to eq first_question_position + 2
          expect(question_group.reload.questions[6].position).to eq first_question_position + 6
        end
      end

      shared_examples 'titles are the same' do
        it 'returns serialized question_group with new questions' do
          expect(json_response['included'][0]['attributes']['title']).to eq 'Shared question Id Title'
          expect(json_response['included'][4]['attributes']['title']).to eq 'Question Id Title'
        end

        it 'shared_question_group questions have proper title' do
          expect(shared_question_group.reload.questions[0].title).to eq 'Shared question Id Title'
          expect(shared_question_group.reload.questions[4].title).to eq 'Question Id Title'
        end
      end

      shared_examples 'positions are proper' do
        it 'shared questions have proper position' do
          expect(json_response['included'][0]['attributes']['position']).to eq first_question_position
          expect(json_response['included'][4]['attributes']['position']).to eq first_question_position + 4
        end

        it 'shared questions have proper positions' do
          expect(shared_question_group.reload.questions[0].position).to eq first_question_position
          expect(shared_question_group.reload.questions[4].position).to eq first_question_position + 4
        end
      end

      shared_examples 'question number is proper' do
        it 'returns proper number of questions' do
          expect(json_response['included'].size).to eq 5
        end

        it 'shared_question_group has proper number of questions' do
          expect(shared_question_group.reload.questions.size).to eq 5
        end
      end

      context 'when question group does not have questions' do
        let!(:other_question_ids) {}

        before { request }

        it 'returns ok status' do
          expect(response).to have_http_status(:ok)
        end

        include_examples 'titles are the same'
        include_examples 'question number is proper'
        include_examples 'positions are proper'
        include_examples 'cleared branching, variables and speech blocks'
      end

      context 'when ids are duplicated' do
        let(:params) do
          {
            question_group: {
              question_ids: question_ids.pluck(:id),
              question_group_ids: [question_group.id],
              shared_qg_id: shared_question_group.id
            }
          }
        end

        before { request }

        it 'returns ok status' do
          expect(response).to have_http_status(:ok)
        end

        include_examples 'titles are the same'
        include_examples 'question number is proper'
        include_examples 'positions are proper'
        include_examples 'cleared branching, variables and speech blocks'
      end
    end

    context 'when parameters are improper' do
      shared_examples 'constant shared_question_group' do
        it 'does not change shared_question_group' do
          expect(shared_question_group.reload.questions.size).to eq 2
        end
      end

      describe '#forbidden' do
        context 'when intervention belongs to other researcher' do
          let!(:other_user) { create(:user, :researcher) }
          let!(:other_intervention) { create(:intervention, user: other_user) }
          let!(:other_session) { create(:session, intervention: other_intervention) }
          let!(:shared_question_group) { create(:question_group_plain, session: other_session, position: 1) }
          let!(:shared_questions) do
            create_list(:question_free_response, 2, title: 'Shared question Id Title', question_group: shared_question_group)
          end

          before { request }

          it 'returns forbidden status' do
            expect(response).to have_http_status(:not_found)
          end

          include_examples 'constant shared_question_group'
        end

        context 'when intervention is published' do
          let!(:published_intervention) { create(:intervention, :published, user: user) }
          let!(:published_session) { create(:session, intervention: published_intervention) }
          let!(:published_question_group) { create(:question_group_plain, session: published_session, position: 1) }
          let!(:request) do
            post share_v1_session_question_group_path(session_id: published_session.id, id: published_question_group.id),
                 params: params, headers: user.create_new_auth_token
          end

          before { request }

          it 'returns forbidden status' do
            expect(response).to have_http_status(:forbidden)
          end

          include_examples 'constant shared_question_group'
        end
      end

      describe '#not_found' do
        context 'when one id of questions is invalid' do
          let(:params) do
            {
              question_group: {
                question_ids: question_ids.pluck(:id) << 'invalid',
                question_group_ids: [other_question_group.id]
              }
            }
          end

          before { request }

          it 'returns not_found status' do
            expect(response).to have_http_status(:not_found)
          end

          include_examples 'constant shared_question_group'
        end

        context 'when one id of question groups is invalid' do
          let(:params) do
            {
              question_group: {
                question_ids: question_ids.pluck(:id),
                question_group_ids: ['invalid']
              }
            }
          end

          before { request }

          it 'returns not_found status' do
            expect(response).to have_http_status(:ok)
          end

          it 'adds only questions from question_ids' do
            expect(shared_question_group.reload.questions.size).to eq 5
          end
        end
      end
    end

    context 'testing validation in sharing questions' do
      let!(:third_intervention) { create(:intervention, user: user) }
      let!(:session_with_name) { create(:session, intervention: third_intervention) }
      let!(:question_group_with_name) { create(:question_group_plain, session: session_with_name, position: 1) }
      let!(:name_question) do
        create(:question_name, title: 'Name Question 1', question_group: question_group_with_name)
      end
      let!(:simple_question1) do
        create(:question_free_response, title: 'Free Response 1', question_group: question_group_with_name)
      end
      let!(:simple_question2) do
        create(:question_free_response, title: 'Free Response 1', question_group: question_group_with_name)
      end

      let!(:other_session_with_name) { create(:session, intervention: third_intervention) }
      let!(:other_question_group_with_name) do
        create(:question_group_plain, session: other_session_with_name, position: 1)
      end
      let!(:other_question_name) do
        create(:question_name, title: 'Name Question 2', question_group: other_question_group_with_name)
      end
      let!(:other_question_group_without_name_in_session_with_name) do
        create(:question_group_plain, session: other_session_with_name, position: 1)
      end

      # rubocop:disable Layout/LineLength
      let!(:request1) { post share_v1_session_question_group_path(session_id: session_with_name.id, id: question_group_with_name.id), params: params, headers: user.create_new_auth_token }
      let!(:request2) { post share_v1_session_question_group_path(session_id: other_session_with_name.id, id: other_question_group_with_name.id), params: params, headers: user.create_new_auth_token }
      let!(:request3) { post share_v1_session_question_group_path(session_id: other_session_with_name.id, id: other_question_group_without_name_in_session_with_name.id), params: params, headers: user.create_new_auth_token }
      let!(:request4) { post share_v1_session_question_group_path(session_id: session_with_name.id, id: question_group_with_name.id), params: params_with_questions, headers: user.create_new_auth_token }
      let!(:request5) { post share_v1_session_question_group_path(session_id: other_session_with_name.id, id: other_question_group_with_name.id), params: params_with_questions, headers: user.create_new_auth_token }
      let!(:request6) { post share_v1_session_question_group_path(session_id: other_session_with_name.id, id: other_question_group_without_name_in_session_with_name.id), params: params_with_questions, headers: user.create_new_auth_token }
      # rubocop:enable Layout/LineLength

      let(:params) do
        {
          question_group: {
            question_ids: [name_question.id]
          }
        }
      end

      let(:params_with_questions) do
        {
          question_group: {
            question_ids: [simple_question1.id, simple_question2.id, name_question.id]
          }
        }
      end

      it 'when Question::Name exist in session return BadRequest' do
        request1
        expect(response).to have_http_status(:unprocessable_entity)
        expect(question_group_with_name.reload.questions.size).to be(3)
      end

      it 'when Question::Name exit in other session and in a group' do
        request2
        expect(response).to have_http_status(:unprocessable_entity)
        expect(other_question_group_with_name.reload.questions.size).to be(1)
      end

      it 'when Question::Name exit in other session but not in a group' do
        request3
        expect(response).to have_http_status(:unprocessable_entity)
        expect(other_question_group_without_name_in_session_with_name.reload.questions.size).to be(0)
      end

      context 'testing rollback when in group is invalid question' do
        it 'when in group of shared questions is Question::Name and exit in group' do
          request4
          expect(response).to have_http_status(:unprocessable_entity)
          expect(question_group_with_name.reload.questions.size).to be(3)
        end

        it 'when in group of shared questions is Question::Name and Question::Name exit in other session and in a group' do
          request5
          expect(response).to have_http_status(:unprocessable_entity)
          expect(other_question_group_with_name.reload.questions.size).to be(1)
        end

        it 'when in group of shared questions is Question::Name and Question::Name exit in other session but not in a group' do
          request6
          expect(response).to have_http_status(:unprocessable_entity)
          expect(other_question_group_without_name_in_session_with_name.reload.questions.size).to be(0)
        end
      end
    end
  end
end
