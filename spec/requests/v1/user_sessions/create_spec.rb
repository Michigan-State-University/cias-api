# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/user_sessions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :confirmed, :guest) }
  let(:preview_session) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }
  let(:user) { participant }
  let(:intervention_user) { admin }
  let(:shared_to) { :anyone }
  let(:status) { :published }
  let(:invitations) { [] }
  let(:intervention) do
    create(:intervention, user: intervention_user, status: status, shared_to: shared_to, invitations: invitations, intervention_accesses: accesses,
                          cat_mh_pool: 10)
  end
  let(:session) { create(:session, intervention: intervention) }
  let(:accesses) { [] }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      user_session: {
        session_id: session.id
      }
    }
  end
  let(:request) { post v1_user_sessions_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      before { post v1_user_sessions_path, params: params }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_user_sessions_path, params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  it_behaves_like 'create user session'

  it_behaves_like 'paused intervention'

  it_behaves_like 'closed session'
end
