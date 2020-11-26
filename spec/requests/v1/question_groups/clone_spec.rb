# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/sessions/:session_id/question_groups/:id/clone', type: :request do
  let(:request) { post clone_v1_session_question_group_path(session_id: session.id, id: question_group.id), headers: headers }

  let!(:session) { create(:session, problem: create(:problem, :published)) }
  let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
  let!(:questions)      { create_list(:question_free_response, 2, question_group: question_group, subtitle: 'Question Subtitle') }

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

    context 'when question group does not have questions' do
      it 'returns serialized cloned question_group' do
        expect { request }
          .to change(QuestionGroup, :count).by(1)
          .and change(Question, :count).by(2)

        expect(response).to have_http_status(:ok)
        expect(json_response['title']).to eq 'Question Group Title'
        expect(json_response['questions'][0]['subtitle']).to eq 'Question Subtitle'
      end
    end
  end
end
