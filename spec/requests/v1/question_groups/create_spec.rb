# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/sessions/:session_id/question_groups', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:researcher_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
  let(:user) { researcher }
  let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:other_session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group) { create(:question_group_plain, session: session, position: 1) }
  let!(:other_question_group) { create(:question_group_plain, session: other_session, position: 1) }
  let!(:question_ids) do
    create_list(:question_free_response, 3, title: 'Question Id Title', question_group: question_group)
  end
  let(:request) do
    post v1_session_question_groups_path(session_id: session.id), params: params, headers: user.create_new_auth_token
  end
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
    shared_examples 'permitted user' do
      context 'when both question_ids and questions are present' do
        it 'returns serialized question_group' do
          request

          expect(response).to have_http_status(:created)
          expect(json_response['data']['attributes']['title']).to eq 'QuestionGroup Title'
          expect(json_response['data']['attributes']['position']).to eq 2
          expect(json_response['data']['relationships']['questions']['data'].size).to eq 5
          expect(json_response['included'][0]['attributes']['title']).to eq 'Question Id Title'
          expect(json_response['included'][4]['attributes']['title']).to eq 'Question Title 2'
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
          expect(json_response['data']['attributes']['title']).to eq 'QuestionGroup Title'
          expect(json_response['data']['attributes']['position']).to eq 2
          expect(json_response['data']['relationships']['questions']['data'].size).to eq 3
          expect(json_response['included'][0]['attributes']['title']).to eq 'Question Id Title'
          expect(json_response['included'][2]['attributes']['title']).to eq 'Question Id Title'
          expect(QuestionGroup.find(json_response['data']['id']).questions.size).to eq question_ids.size
          expect { QuestionGroup.find(question_group.id) }.to raise_error(ActiveRecord::RecordNotFound)
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
          expect(json_response['data']['attributes']['title']).to eq 'QuestionGroup Title'
          expect(json_response['data']['attributes']['position']).to eq 2
          expect(json_response['data']['relationships']['questions']['data'].size).to eq 2
          expect(json_response['included'][0]['attributes']['title']).to eq 'Question Title 1'
          expect(json_response['included'][1]['attributes']['title']).to eq 'Question Title 2'
        end
      end
    end

    context 'user is researcher' do
      it_behaves_like 'permitted user'
    end

    context 'user is researcher and also have other roles' do
      let(:user) { researcher_with_multiple_roles }

      it_behaves_like 'permitted user'
    end
  end

  context 'when the editor creates a single answer question group' do
    let!(:new_session) { create(:session, intervention: create(:intervention, user: researcher)) }
    let(:single_question) do
      {
        type: 'Question::Single',
        title: '<p>Q</p>',
        subtitle: '<p>S</p>',
        settings: { image: false, title: true, video: false, required: true, subtitle: true },
        body: { data: [{ payload: '<p>Yes</p>', value: '1' }], variable: { name: 'created_var' } },
        narrator: { blocks: [], settings: { voice: true, animation: true, character: 'peedy' } }
      }
    end
    let(:group_params) { { title: 'Created group', type: 'QuestionGroup::Plain', questions: [single_question] } }
    let(:request) do
      post v1_session_question_groups_path(session_id: new_session.id),
           params: { question_group: group_params }, headers: researcher.create_new_auth_token, as: :json
    end
    let(:plain_groups) { new_session.reload.question_groups.where(type: 'QuestionGroup::Plain') }

    it 'returns the group with its question and gives every answer an id' do
      request

      expect(response).to have_http_status(:created)
      group = json_response['data']
      question = json_response['included'].first
      expect(group['attributes']).to include('title' => 'Created group', 'type' => 'QuestionGroup::Plain')
      expect(question['attributes']['type']).to eq('Question::Single')
      expect(question['attributes']['body']['data'])
        .to match([include('id' => match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/))])
    end

    context 'when question_group is not a hash' do
      let(:group_params) { 'not a hash' }

      it 'is rejected with 400 and creates nothing' do
        expect { request }.not_to change(QuestionGroup, :count)
        expect(response).to have_http_status(:bad_request)
        expect(json_response.keys).to eq(['message'])
      end
    end
  end
end
