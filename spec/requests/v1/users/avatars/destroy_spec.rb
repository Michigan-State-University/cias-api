# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/users/:user_id/avatars', type: :request do
  let(:current_user) { create(:user, :confirmed, :admin, avatar: Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }
  let(:other_user) { create(:user, :confirmed, :participant, avatar: Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }
  let(:user_id) { current_user.id }

  before { delete v1_user_avatars_path(user_id), headers: current_user.create_new_auth_token }

  context 'when current_user is admin' do
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

  context 'when current_user is researcher' do
    let(:current_user) { create(:user, :confirmed, :researcher, avatar: Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }

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
    let(:current_user) { create(:user, :confirmed, :participant, avatar: Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }

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
    let(:current_user) { create(:user, :confirmed, :guest, avatar: Rack::Test::UploadedFile.new('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)) }

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
