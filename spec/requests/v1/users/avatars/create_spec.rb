# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/users/:user_id/avatars', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }

  let(:other_user) { create(:user, :confirmed, :participant) }

  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:params) do
    {
      avatar: {
        file: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
      }
    }
  end
  let(:user_id) { current_user.id }
  let(:current_user) { admin }

  before { post v1_user_avatars_path(user_id), params: params, headers: current_user.create_new_auth_token }

  shared_examples 'permitted user' do
    context 'when current_user updates itself' do
      it { expect(response).to have_http_status(:created) }

      it 'JSON response contains proper attributes' do
        avatar_url = polymorphic_url(current_user.reload.avatar).sub('http://www.example.com/', '')
        expect(json_response['data']['attributes']).to include(
          'email' => current_user.email,
          'avatar_url' => include(avatar_url)
        )
      end

      it 'attaches avatar to the current user' do
        expect(current_user.avatar.attachment.attributes).to include(
          'record_type' => 'User',
          'record_id' => current_user.id,
          'name' => 'avatar'
        )
      end
    end
  end

  context 'when current_user is admin' do
    %w[admin admin_with_multiple_roles].each do |role|
      context 'when user updates his avatar' do
        let(:current_user) { users[role] }

        it_behaves_like 'permitted user'
      end

      context 'when current_user updates other user' do
        let(:user_id) { other_user.id }

        it { expect(response).to have_http_status(:created) }

        it 'JSON response contains proper attributes' do
          avatar_url = polymorphic_url(other_user.reload.avatar).sub('http://www.example.com/', '')
          expect(json_response['data']['attributes']).to include(
            'email' => other_user.email,
            'avatar_url' => include(avatar_url)
          )
        end

        it 'attaches avatar to the current user' do
          expect(other_user.avatar.attachment.attributes).to include(
            'record_type' => 'User',
            'record_id' => other_user.id,
            'name' => 'avatar'
          )
        end
      end
    end
  end

  %w[guest participant e_intervention_admin team_admin organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context "when current_user is #{role}" do
      let(:current_user) { create(:user, :confirmed, role) }

      context 'when current_user updates itself' do
        it_behaves_like 'permitted user'
      end

      context 'when current_user updates other user' do
        let(:user_id) { other_user.id }

        it { expect(response).to have_http_status(:not_found) }
      end
    end
  end

  context 'when user is researcher' do
    let(:current_user) { create(:user, :confirmed, :researcher) }

    context 'when current_user updates itself' do
      it_behaves_like 'permitted user'
    end

    context 'when current_user updates other user' do
      let(:user_id) { other_user.id }

      it { expect(response).to have_http_status(:forbidden) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq 'You are not authorized to access this page.'
      end
    end
  end
end
