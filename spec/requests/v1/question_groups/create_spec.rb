# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/interventions/:intervention_id/question_groups', type: :request do
  let(:request) { post v1_intervention_question_groups_path(intervention_id: intervention.id), params: params, headers: headers }
  let(:params) do
    {
      question_group: {
        title: 'QuestionGroup Title',
        position: 1,
        questions: questions.pluck(:id)
      }
    }
  end

  let!(:intervention) { create(:intervention, problem: create(:problem, :published)) }
  let!(:questions)    { create_list(:question_free_response, 3, title: 'Question Title') }

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns forbidden status' do
      request

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    it 'returns serialized question_group' do
      expect { request }.to change(QuestionGroup, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['title']).to eq 'QuestionGroup Title'
      expect(json_response['questions'].size).to eq 3
      expect(json_response['questions'][0]['title']).to eq 'Question Title'
    end
  end
end
