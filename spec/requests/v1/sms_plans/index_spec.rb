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
    let!(:sms_plan1) { create(:sms_plan) }
    let!(:sms_plan2) { create(:sms_plan) }

    before do
      request
    end

    shared_examples 'permitted user' do
      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns sms plans' do
        expect(
          json_response['data'].pluck('id')
        ).to match_array [sms_plan1.id, sms_plan2.id]
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
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

  context 'when filter params are present' do
    let!(:sms_plan1) { create(:sms_plan) }
    let!(:sms_alert1) { create(:sms_alert) }
    let!(:sms_plan2) { create(:sms_plan) }
    let!(:sms_alert2) { create(:sms_alert) }
    let!(:params) { {} }

    let(:request) { get v1_sms_plans_path, headers: headers, params: params }

    before do
      request
    end

    context 'filter only sms alerts' do
      let!(:params) { { types: ['SmsPlan::Alert'] } }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it "returns correct id's" do
        expect(
          json_response['data'].pluck('id')
        ).to match_array [sms_alert1.id, sms_alert2.id]
      end
    end

    context 'filter only sms plans' do
      let!(:params) { { types: ['SmsPlan::Normal'] } }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it "returns correct id's" do
        expect(
          json_response['data'].pluck('id')
        ).to match_array [sms_plan1.id, sms_plan2.id]
      end
    end
  end
end
