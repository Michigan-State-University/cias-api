# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/sessions/:session_id/question_groups/:id/remove_questions', type: :request do
  let(:request) do
    delete remove_questions_v1_session_question_group_path(session_id: session.id, id: question_group.id), params: params,
                                                                                                           headers: headers
  end
  let(:params) do
    {
      question_group: {
        question_ids: questions.pluck(:id)
      }
    }
  end

  let!(:session) { create(:session, intervention: create(:intervention, :published)) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:questions)      { create_list(:question_free_response, 2, question_group: question_group) }

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns forbidden status' do
      request

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authenticated as admin user' do
    let(:admin) { create(:user, :confirmed, :admin) }
    let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
    let(:user) { admin }
    let(:users) do
      {
        'admin' => admin,
        'admin_with_multiple_roles' => admin_with_multiple_roles
      }
    end
    let(:headers) { user.create_new_auth_token }

    context 'one or multiple roles' do
      %w[admin admin_with_multiple_roles].each do |_role|
        it 'returns serialized question_group' do
          expect { request }.to change { question_group.questions.count }.by(-2)

          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
