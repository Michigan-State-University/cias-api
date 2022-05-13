# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/sessions/:session_id/question_groups/:id', type: :request do
  let(:request) do
    delete v1_session_question_group_path(session_id: session.id, id: question_group.id), headers: headers
  end

  let!(:session) { create(:session, intervention: create(:intervention, :published)) }
  let!(:question_group) { create(:question_group, session: session, title: 'QuestionGroup Title') }
  let!(:questions) { create_list(:question_free_response, 3, title: 'Question Title', question_group: question_group) }

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
        it 'returns no_content status and removes QuestionGroup' do
          expect { request }.to change(QuestionGroup, :count).by(-1)

          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
