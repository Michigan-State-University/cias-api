# frozen_string_literal: true

RSpec.describe 'POST /v1/sessions/:session_id/question_group/duplicate_here', type: :request do
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, user: researcher) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_groups) do
    create_list(:question_group, 3, session: session)
  end
  let!(:question_in_first_group) do
    create_list(:question_single, 4, question_group: question_groups[0])
  end
  let!(:question_in_second_group) do
    create_list(:question_multiple, 3, question_group: question_groups[1])
  end
  let!(:question_in_third_group) do
    create_list(:question_grid, 2,  question_group: question_groups[2])
  end
  let(:params) do
    {
      question_groups: [
        {
          id: question_groups[0].id,
          question_ids: [question_in_first_group[0].id, question_in_first_group[3].id]
        },
        {
          id: question_groups[2].id,
          question_ids: [question_in_third_group[0].id]
        }
      ]
    }
  end
  let(:request) do
    post v1_session_duplicate_question_groups_with_structure_path(session_id: session.id), headers: researcher.create_new_auth_token, params: params
  end

  context 'all params are valid' do
    it 'create question group and questions' do
      expect { request }.to change(QuestionGroup, :count).by(2).and change(Question, :count).by(3)
    end

    it 'return correct response' do
      request
      expect(json_response['data'].count).to be(2)
      expect(json_response['data'].first['type']).to eql('question_group')
      expect(json_response['included'].count).to be(3)
    end

    it 'session has correct number of group' do
      request
      expect(session.reload.question_groups.count).to be(6)
    end
  end

  context 'permission isn\'t correct' do
    context 'other researcher' do
      let(:other_researcher) { create(:user, :researcher, :confirmed) }
      let(:request) do
        post v1_session_duplicate_question_groups_with_structure_path(session_id: session.id), headers: other_researcher.create_new_auth_token, params: params
      end

      before { request }

      it 'return correct status' do
        expect(response).to have_http_status(:not_found)
      end

      it 'return correct msg' do
        expect(json_response['message']).to include("Couldn't find Session with 'id'")
      end
    end

    context 'participant' do
      let(:participant) { create(:user, :participant, :confirmed) }
      let(:request) do
        post v1_session_duplicate_question_groups_with_structure_path(session_id: session.id), headers: participant.create_new_auth_token, params: params
      end

      before { request }

      it 'return correct status' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'return correct msg' do
        expect(json_response['message']).to include('You are not authorized to access this page.')
      end
    end
  end

  context 'params are invalid' do
    let(:params) do
      {
        question_groups: [
          {
            id: question_groups[0].id,
            question_ids: [question_in_first_group[0].id, question_in_first_group[3].id]
          },
          {
            id: question_groups[2].id,
            question_ids: [question_in_second_group[0].id]
          }
        ]
      }
    end

    it 'didn\'t add any group' do
      expect { request }.to change(QuestionGroup, :count).by(0).and change(Question, :count).by(0)
    end

    it 'return correct status and msg' do
      request
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include("Couldn't find Question with 'id'")
    end
  end
end
