# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/question_groups/:question_group_id/questions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:question) { create(:question_slider, question_group: question_group) }
  let(:question_group) { create(:question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_question_group_question_path(question_group_id: question_group.id, id: question.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_question_group_question_path(question_group_id: question_group.id, id: question.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when response' do
        context 'is JSON' do
          before { request }

          it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
        end

        context 'contains' do
          before { request }

          it 'to hash success' do
            expect(json_response.class).to be(Hash)
          end

          it 'key question' do
            expect(json_response['data']['type']).to eq('question')
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'invalid question id' do
    before do
      get v1_question_group_question_path(question_group_id: question_group.id, id: 'invalid'), headers: headers
    end

    it 'returns not found http status' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
