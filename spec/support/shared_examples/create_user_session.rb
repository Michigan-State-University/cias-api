# frozen_string_literal: true

RSpec.shared_examples 'create user session' do
  context 'when params' do
    context 'valid' do
      before do
        request
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          post v1_fetch_or_create_user_sessions_path, params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end

  context 'user session' do
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

      it 'has the "started" flag set to true' do
        request
        expect(json_response['data']['attributes']['started']).to be true
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

        it 'has the "started" flag set to true' do
          request
          expect(json_response['data']['attributes']['started']).to be true
        end
      end
    end

    context 'when quick exit is turn on' do
      let(:intervention) do
        create(:intervention, :published, user: intervention_user, quick_exit: true)
      end

      it 'returns correct status' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'update user object' do
        request
        expect(user.reload.quick_exit_enabled).to be true
      end
    end
  end

  context 'session access' do
    before { post v1_fetch_or_create_user_sessions_path, params: params, headers: headers }

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
          expect(response).to have_http_status(:forbidden)
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
