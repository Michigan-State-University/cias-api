# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/interventions/:intervention_id/question_groups', type: :request do
  let!(:user) { create(:user, :researcher) }
  let!(:intervention) { create(:intervention, problem: create(:problem, user: user)) }
  let(:questions) { create_list(:question_free_response, 3, title: 'Question Title', question_group_id: intervention.question_group_default.id) }
  let(:request) { post v1_intervention_question_groups_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }
  let(:params) do
    {
      question_group: {
        title: 'QuestionGroup Title',
        position: 1,
        questions: questions.pluck(:id)
      }
    }
  end

  context 'when authenticated as researcher user' do
    it 'returns serialized question_group' do
      intervention.reload
      questions
      request

      expect(response).to have_http_status(:created)
      expect(json_response['title']).to eq 'QuestionGroup Title'
      expect(json_response['questions'].size).to eq 3
      expect(json_response['questions'][0]['title']).to eq 'Question Title'
    end
  end
end
