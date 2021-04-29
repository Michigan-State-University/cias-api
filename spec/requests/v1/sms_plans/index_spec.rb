# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sms_plans', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_sms_plans_path, headers: headers }

  context 'when there are sms plans' do
    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }
      let!(:sms_plan_1) { create(:sms_plan) }
      let!(:sms_plan_2) { create(:sms_plan) }

      before do
        request
      end

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns sms plans' do
        expect(
          json_response['data'].pluck('id')
        ).to match_array [sms_plan_1.id, sms_plan_2.id]
      end
    end
  end

  context 'when there are no sms plans' do
    before do
      request
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'success to Hash' do
      expect(json_response['data']).to be_empty
    end
  end
end
