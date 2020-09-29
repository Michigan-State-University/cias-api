# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/interventions/:intervention_id/question_groups/:id', type: :request do
  let(:request) { delete v1_intervention_question_group_path(intervention_id: intervention.id, id: question_group.id), headers: headers }

  let!(:intervention)   { create(:intervention, problem: create(:problem, :published)) }
  let!(:question_group) { create(:question_group, intervention: intervention, title: 'QuestionGroup Title') }
  let!(:questions)      { create_list(:question_free_response, 3, title: 'Question Title', question_group: question_group) }

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

    it 'returns no_content status and removes QuestionGroup' do
      expect { request }.to change(QuestionGroup, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
