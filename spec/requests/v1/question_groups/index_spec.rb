# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/sessions/:session_id/question_groups', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }

  let!(:intervention) { create(:intervention, status: intervention_status, invitations: users_with_accesses, shared_to: shared_to, user: intervention_user) }

  let!(:session) { create(:session, intervention: intervention) }
  let(:shared_to) { :anyone }
  let(:intervention_status) { :published }
  let(:intervention_user) { admin }
  let(:users_with_accesses) { [] }

  let!(:question_groups) { create_list(:question_group, 3, session: session) }

  before { get v1_session_question_groups_path(session_id: session.id), headers: user.create_new_auth_token }

  context 'when user has role admin' do
    context 'and intervention status is published' do
      context 'with anyone with link access setting' do
        context 'admin want to access his intervention question groups' do
          let(:intervention_user) { admin }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end

        context 'admin wants to access researcher intervention question groups' do
          let(:intervention_user) { researcher }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'with only registered participant access setting' do
        let(:shared_to) { :registered }

        context 'admin wants to access his intervention question groups' do
          let(:intervention_user) { admin }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end

        context 'admin wants to access researcher intervention question groups' do
          let(:intervention_user) { researcher }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'with only selected registered participant access setting' do
        let(:shared_to) { :invited }

        context 'admin wants to access his intervention question groups' do
          let(:intervention_user) { admin }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end

        context 'admin wants to access researcher intervention question groups' do
          let(:intervention_user) { researcher }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'when intervention is draft' do
      let(:intervention_status) { :draft }

      context 'admin wants to access his intervention question groups' do
        let(:intervention_user) { admin }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'has correct size of question groups' do
          expect(json_response['question_groups'].size).to eq(4)
        end
      end

      context 'admin wants to access researcher intervention question groups' do
        let(:intervention_user) { researcher }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  context 'when user has role researcher' do
    let(:user) { researcher }

    context 'and intervention status is published' do
      context 'with anyone with link access setting' do
        context 'researcher wants to access admin intervention question groups' do
          let(:intervention_user) { admin }

          it 'returns correct not_found http status' do
            expect(response).to have_http_status(:not_found)
          end

          it 'returns correct not_found message' do
            expect(json_response['message']).to eq('Session not found')
          end
        end

        context 'researcher wants access his intervention question groups' do
          let(:intervention_user) { researcher }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end
      end

      context 'with only registered participant access setting' do
        let(:shared_to) { :registered }

        context 'researcher wants to access admin intervention question groups' do
          let(:intervention_user) { admin }

          it 'returns correct not_found http status' do
            expect(response).to have_http_status(:not_found)
          end

          it 'returns correct not_found message' do
            expect(json_response['message']).to eq('Session not found')
          end
        end

        context 'researcher wants to access his intervention question groups' do
          let(:intervention_user) { researcher }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end
      end

      context 'with only selected registered participant access setting' do
        let(:shared_to) { :invited }

        context 'researcher wants to access admin intervention question groups' do
          let(:intervention_user) { admin }

          it 'returns correct not_found http status' do
            expect(response).to have_http_status(:not_found)
          end

          it 'returns correct not_found message' do
            expect(json_response['message']).to eq('Session not found')
          end
        end

        context 'researcher wants to access his intervention question groups' do
          let(:intervention_user) { researcher }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end
      end
    end

    context 'when intervention is draft' do
      let(:intervention_status) { :draft }

      context 'researcher wants to access admin intervention question groups' do
        let(:intervention_user) { admin }

        it 'returns correct not_found http status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns correct not_found message' do
          expect(json_response['message']).to eq('Session not found')
        end
      end

      context 'researcher wants to access his intervention question groups' do
        let(:intervention_user) { researcher }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    context 'and intervention status is published' do
      context 'with anyone with link access setting' do
        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'has correct size of question groups' do
          expect(json_response['question_groups'].size).to eq(4)
        end

        context 'with only registered participant access setting' do
          let(:shared_to) { :registered }

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'has correct size of question groups' do
            expect(json_response['question_groups'].size).to eq(4)
          end
        end

        context 'with only selected registered participant access setting' do
          let(:shared_to) { :invited }

          context 'and participant was not selected' do
            it 'returns correct not_found http status' do
              expect(response).to have_http_status(:not_found)
            end

            it 'returns correct not_found message' do
              expect(json_response['message']).to eq('Session not found')
            end
          end

          context 'and participant was selected' do
            let(:users_with_accesses) { [build(:intervention_invitation, email: participant.email)] }

            it 'returns correct http status' do
              expect(response).to have_http_status(:ok)
            end

            it 'has correct size of question groups' do
              expect(json_response['question_groups'].size).to eq(4)
            end
          end
        end
      end

      context 'when intervention is draft' do
        let(:intervention_status) { :draft }

        it 'returns correct not_found http status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns correct not_found message' do
          expect(json_response['message']).to eq('Session not found')
        end
      end
    end
  end

  context 'when user has role guest' do
    let(:user) { guest }

    context 'and intervention status is published' do
      context 'with anyone with link access setting' do
        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'has correct size of question groups' do
          expect(json_response['question_groups'].size).to eq(4)
        end
      end

      context 'with only registered participant access setting' do
        let(:shared_to) { :registered }

        it 'returns correct not_found http status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns correct not_found message' do
          expect(json_response['message']).to eq('Session not found')
        end
      end

      context 'with only selected registered participant access setting' do
        let(:shared_to) { :invited }

        it 'returns correct not_found http status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns correct not_found message' do
          expect(json_response['message']).to eq('Session not found')
        end
      end
    end

    context 'when intervention is draft' do
      let(:intervention_status) { :draft }

      it 'returns correct not_found http status' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns correct not_found message' do
        expect(json_response['message']).to eq('Session not found')
      end
    end
  end
end
