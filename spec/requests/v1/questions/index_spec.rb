# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:qusetion_group_id/questions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:question_group) { create(:question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_question_group_questions_path(question_group.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_question_group_questions_path(question_group.id) }

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

        context 'is JSON and parse' do
          before { request }

          it 'success to Hash' do
            expect(json_response.class).to be(Hash)
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end
end
