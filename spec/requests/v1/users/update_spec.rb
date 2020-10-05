# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/users/:id', type: :request do
  let(:current_user) { create(:user, :admin, first_name: 'Smith', last_name: 'Wazowski') }
  let(:other_user) { create(:user, :confirmed) }
  let(:params) do
    {
      user: {
        first_name: 'John',
        last_name: 'Kowalski'
      }
    }
  end
  let(:user_id) { current_user.id }

  before { patch v1_user_path(user_id), headers: current_user.create_new_auth_token, params: params }

  context 'when current_user is admin' do
    context 'when current_user updates itself' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski',
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'updates user attributes' do
        expect(current_user.reload.attributes).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski'
        )
      end

      context 'when current_user tries to update deactivated and roles attributes' do
        let(:params) do
          {
            user: {
              roles: %w[admin guest],
              active: false
            }
          }
        end

        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response).to include(
            'roles' => %w[admin guest],
            'active' => false
          )
        end

        it 'updates user attributes' do
          expect(current_user.reload.attributes).to include(
            'roles' => %w[admin guest],
            'active' => false
          )
        end
      end
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski',
          'email' => other_user.email,
          'avatar_url' => nil
        )
      end

      it 'updates user attributes' do
        expect(other_user.reload.attributes).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski'
        )
      end

      context 'when current_user tries to update deactivated and roles attributes' do
        let(:params) do
          {
            user: {
              roles: %w[admin guest],
              active: false
            }
          }
        end

        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response).to include(
            'roles' => %w[admin guest],
            'active' => false
          )
        end

        it 'updates user attributes' do
          expect(other_user.reload.attributes).to include(
            'roles' => %w[admin guest],
            'active' => false
          )
        end
      end
    end
  end

  context 'when current_user is researcher' do
    let(:current_user) { create(:user, :confirmed, :researcher, first_name: 'Smith', last_name: 'Wazowski') }

    context 'when current_user updates itself' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski',
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'updates user attributes' do
        expect(current_user.reload.attributes).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski'
        )
      end

      context 'when current_user tries to update deactivated and roles attributes' do
        let(:params) do
          {
            user: {
              roles: %w[admin guest],
              deactivated: true
            }
          }
        end

        it { expect(response).to have_http_status(:forbidden) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq 'You are not authorized to access this page.'
        end
      end
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:forbidden) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq 'You are not authorized to access this page.'
      end
    end
  end

  context 'when current_user is participant' do
    let(:current_user) { create(:user, :confirmed, :participant, first_name: 'Smith', last_name: 'Wazowski') }

    context 'when current_user updates itself' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski',
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'updates user attributes' do
        expect(current_user.reload.attributes).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski'
        )
      end

      context 'when current_user tries to update deactivated and roles attributes' do
        let(:params) do
          {
            user: {
              roles: %w[admin guest],
              deactivated: true
            }
          }
        end

        it { expect(response).to have_http_status(:forbidden) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq 'You are not authorized to access this page.'
        end
      end
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  context 'when current_user is guest' do
    let(:current_user) { create(:user, :confirmed, :guest, first_name: 'Smith', last_name: 'Wazowski') }

    context 'when current_user updates itself' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski',
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'updates user attributes' do
        expect(current_user.reload.attributes).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski'
        )
      end

      context 'when current_user tries to update deactivated and roles attributes' do
        let(:params) do
          {
            user: {
              roles: %w[admin guest],
              deactivated: true
            }
          }
        end

        it { expect(response).to have_http_status(:forbidden) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq 'You are not authorized to access this page.'
        end
      end
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
