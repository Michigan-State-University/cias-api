# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_user_path(id: alter_user.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_user_path(id: alter_user.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is admin' do
    context 'when response' do
      context 'is success' do
        before { request }

        it { expect(response).to have_http_status(:no_content) }
      end

      context 'not found' do
        before do
          delete v1_user_path(id: 'invalid'), headers: headers
        end

        it { expect(response).to have_http_status(:not_found) }
      end
    end
  end

  %w[guest participant researcher e_intervention_admin team_admin organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context "when user is #{role}" do
      let(:user) { create(:user, :confirmed, role) }

      context 'when response is not_found' do
        before { request }

        it { expect(response).to have_http_status(:not_found) }
      end
    end
  end
end
