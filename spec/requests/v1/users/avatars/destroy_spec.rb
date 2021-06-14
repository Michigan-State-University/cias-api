# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/users/:user_id/avatars', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:other_user) { create(:user, :confirmed, :participant, avatar: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }
  let(:user_id) { current_user.id }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end

  before { delete v1_user_avatars_path(user_id), headers: current_user.create_new_auth_token }

  context 'when current_user is admin' do
    shared_examples 'permitted user' do
      context 'when current_user updates own avatar' do
        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'email' => current_user.email,
            'avatar_url' => nil
          )
        end

        it 'removes attached avatar' do
          expect(current_user.reload.avatar.attachment).to eq nil
        end
      end

      context 'when current_user updates other user' do
        let(:user_id) { other_user.id }

        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'email' => other_user.email,
            'avatar_url' => nil
          )
        end

        it 'removes attached avatar' do
          expect(other_user.reload.avatar.attachment).to eq nil
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:current_user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'when current_user is researcher' do
    let(:current_user) { create(:user, :confirmed, :researcher, avatar: FactoryHelpers.upload_filew('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }

    context 'when current_user updates own avatar' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'removes attached avatar' do
        expect(current_user.reload.avatar.attachment).to eq nil
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
    let(:current_user) { create(:user, :confirmed, :participant, avatar: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }

    context 'when current_user updates own avatar' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'removes attached avatar' do
        expect(current_user.reload.avatar.attachment).to eq nil
      end
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  context 'when current_user is guest' do
    let(:current_user) { create(:user, :confirmed, :guest, avatar: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }

    context 'when current_user updates own avatar' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'removes attached avatar' do
        expect(current_user.reload.avatar.attachment).to eq nil
      end
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
