# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/user_sessions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :confirmed, :guest) }
  let(:preview_session) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }
  let(:user) { admin }
  let(:intervention_user) { admin }
  let(:shared_to) { :anyone }
  let(:status) { :draft }
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

  context 'when auth' do
    context 'is invalid' do
      before { post v1_user_sessions_path, params: params }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_user_sessions_path, params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when params' do
    context 'valid' do
      before do
        post v1_user_sessions_path, params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          post v1_user_sessions_path, params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end

  context 'user session' do
    let(:request) { post v1_user_sessions_path, params: params, headers: headers }

    context 'does not exist' do
      it 'returns correct status' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'creates user session' do
        expect { request }.to change(UserSession, :count).by(1)
      end

      it 'user session have correct type' do
        request
        expect(json_response['data']['attributes']['type']).to eql('UserSession::Classic')
      end

      context 'create UserSession::CatMh' do
        let(:session) { create(:cat_mh_session, :with_cat_mh_info, intervention: intervention) }

        it 'user session have correct type' do
          request
          expect(json_response['data']['attributes']['type']).to eql('UserSession::CatMh')
        end

        it 'created_cat_mh_session_counter in intervention should be incremented' do
          request
          expect(intervention.reload.created_cat_mh_session_count).to be(1)
        end

        context 'when intervention did\'t have permission' do
          let(:intervention) { create(:intervention, user: intervention_user, status: status, shared_to: shared_to, invitations: invitations, cat_mh_pool: 0) }

          it 'return forbidden status' do
            request
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'when intervention has not set cat_mh_pool' do
          let(:intervention) { create(:intervention, user: intervention_user, status: status, shared_to: shared_to, invitations: invitations) }

          it 'return forbidden status' do
            request
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    context 'exists' do
      let!(:user_int) { create(:user_intervention, intervention: intervention, user: user, status: 'in_progress') }
      let!(:user_session) { create(:user_session, user: user, session: session, user_intervention: user_int) }

      it 'returns correct status' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'does not create user session' do
        request
        expect { request }.to change(UserSession, :count).by(0)
      end

      it 'returns correct user_session_id' do
        request
        expect(json_response['data']['id']).to eq(user_session.id)
      end
    end
  end

  context 'session access' do
    before { post v1_user_sessions_path, params: params, headers: headers }

    context 'user is admin' do
      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct data' do
        expect(json_response['data']['type']).to eq('user_session')
      end
    end

    context 'user is researcher' do
      let(:user) { researcher }

      context 'access admin session' do
        it 'returns correct http status' do
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'access his session' do
        let(:intervention_user) { researcher }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns correct data' do
          expect(json_response['data']['type']).to eq('user_session')
        end
      end
    end

    context 'user is participant' do
      let(:user) { participant }
      let(:status) { :published }

      context 'access admin session shared to anyone with the link' do
        %w[draft closed archived].each do |status|
          context "intervention status is #{status}" do
            let(:status) { status }

            it 'returns correct http status' do
              expect(response).to have_http_status(:forbidden)
            end
          end
        end
        context 'intervention status is published' do
          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'shared to only registered participants' do
        let(:shared_to) { :registered }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end
      end

      context 'shared to only invited registered participants' do
        let(:shared_to) { :invited }

        context 'participant was not invited' do
          it 'returns correct http status' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'participant was invited' do
          let(:accesses) { [build(:intervention_access, email: participant.email)] }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'user is guest' do
      let(:user) { guest }
      let(:status) { :published }

      context 'shared to anyone' do
        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end
      end

      context 'shared to only registered participants' do
        let(:shared_to) { :registered }

        it 'returns correct http status' do
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'shared to only invited registered participants' do
        let(:shared_to) { :invited }

        context 'participant was not invited' do
          it 'returns correct http status' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'participant was invited' do
          let(:invitations) { [build(:intervention_invitation, email: guest.email)] }

          it 'returns correct http status' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    context 'user is preview session' do
      let(:user) { preview_session }

      %w[published closed archived].each do |status|
        context "intervention status is #{status}" do
          let(:status) { status }

          it 'returns correct http status' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
      context 'intervention status is draft' do
        let(:status) { :draft }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
