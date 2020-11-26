# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/problems/:problem_id/sessions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:problem) { create(:problem) }
  let(:session) { create(:session, problem: problem) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      session: {
        name: 'test1 params',
        body: {
          payload: 1,
          target: '',
          variable: '1'
        }
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { patch v1_problem_session_path(problem_id: problem.id, id: session.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { patch v1_problem_session_path(problem_id: problem.id, id: session.id), params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when params' do
    context 'valid' do
      before do
        session.reload
        patch v1_problem_session_path(problem_id: problem.id, id: session.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          session.reload
          patch v1_problem_session_path(problem_id: problem.id, id: session.id), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
