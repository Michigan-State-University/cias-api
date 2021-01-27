# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/sessions/:session_id/question_groups', type: :request do
  let!(:user) { create(:user, :researcher) }
  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:other_session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group) { create(:question_group_plain, session: session, position: 1) }
  let!(:other_question_group) { create(:question_group_plain, session: other_session, position: 1) }
  let!(:question_ids) { create_list(:question_free_response, 3, title: 'Question Id Title', question_group: question_group) }
  let(:request) { post v1_session_question_groups_path(session_id: session.id), params: params, headers: user.create_new_auth_token }
  let!(:question_array_json) do
    questions = []
    2.times do |i|
      question = {
        title: "Question Title #{i + 1}",
        type: Question::FollowUpContact,
        body: {
          data: [
            {
              payload: '',
              value: ''
            },
            {
              payload: 'example2',
              value: ''
            }
          ],
          variable: {
            name: ''
          }
        }
      }
      questions << question
    end
    questions
  end

  let(:params) do
    {
      question_group: {
        title: 'QuestionGroup Title',
        session_id: session.id,
        question_ids: question_ids.pluck(:id),
        questions: question_array_json
      }
    }
  end

  context 'when authenticated as researcher user' do
    context 'when both question_ids and questions are present' do
      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:created)
        expect(json_response['title']).to eq 'QuestionGroup Title'
        expect(json_response['position']).to eq 2
        expect(json_response['questions'].size).to eq 5
        expect(json_response['questions'][0]['title']).to eq 'Question Id Title'
        expect(json_response['questions'][4]['title']).to eq 'Question Title 2'
      end
    end

    context 'when only question_ids are present' do
      let(:params) do
        {
          question_group: {
            title: 'QuestionGroup Title',
            session_id: session.id,
            question_ids: question_ids.pluck(:id)
          }
        }
      end

      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:created)
        expect(json_response['title']).to eq 'QuestionGroup Title'
        expect(json_response['position']).to eq 2
        expect(json_response['questions'].size).to eq 3
        expect(json_response['questions'][0]['title']).to eq 'Question Id Title'
        expect(json_response['questions'][2]['title']).to eq 'Question Id Title'
      end
    end

    context 'when only questions are present' do
      let(:params) do
        {
          question_group: {
            title: 'QuestionGroup Title',
            session_id: session.id,
            questions: question_array_json
          }
        }
      end

      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:created)
        expect(json_response['title']).to eq 'QuestionGroup Title'
        expect(json_response['position']).to eq 2
        expect(json_response['questions'].size).to eq 2
        expect(json_response['questions'][0]['title']).to eq 'Question Title 1'
        expect(json_response['questions'][1]['title']).to eq 'Question Title 2'
      end
    end
  end
end
