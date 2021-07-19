# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/sessions/:session_id/question_groups/:id', type: :request do
  let(:request) do
    patch v1_session_question_group_path(session_id: session.id, id: question_group.id),
          params: params, headers: headers
  end
  let(:params) do
    {
      question_group: {
        title: 'New Title'
      }
    }
  end

  let!(:session) { create(:session, intervention: create(:intervention, :published)) }
  let!(:question_group) { create(:question_group_plain, title: 'Old Title', session: session) }

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

    shared_examples 'permitted user' do
      context 'when new title is provided in params' do
        it 'returns serialized question_group' do
          request

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attributes']['title']).to eq 'New Title'
        end
      end

      context 'when new session_id is provided in params' do
        let(:new_session) { create(:session) }
        let(:params) do
          {
            question_group: {
              session_id: new_session.id
            }
          }
        end

        it 'returns serialized question_group' do
          request

          expect(response).to have_http_status(:ok)
          expect(json_response['data']['attributes']['session_id']).to eq new_session.id
        end
      end
    end

    context 'one or multiple roles' do
      %w[admin admin_with_multiple_roles].each do |_role|
        it_behaves_like 'permitted user'
      end
    end
  end
end
