# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/interventions/:intervention_id/question_groups/:id', type: :request do
  let(:request) { get v1_intervention_question_group_path(intervention_id: intervention.id, id: question_group.id), headers: headers }

  let!(:intervention)   { create(:intervention, problem: create(:problem, :published)) }
  let!(:question_group) { create(:question_group, intervention: intervention, title: 'QuestionGroup Title') }
  let!(:questions)      { create_list(:question_free_response, 3, title: 'Question Title', question_group: question_group) }

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns serialized question_group' do
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['title']).to eq 'QuestionGroup Title'
      expect(json_response['questions'][0]['title']).to eq 'Question Title'
    end
  end
end
