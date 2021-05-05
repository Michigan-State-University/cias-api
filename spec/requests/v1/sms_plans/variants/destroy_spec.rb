# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sms_plans/:sms_plan_id/variants/:id', type: :request do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
  let!(:variant_id) { variant.id }
  let(:request) { delete v1_sms_plan_variant_path(sms_plan_id: sms_plan.id, id: variant_id), headers: headers }
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

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when variant with given id exists' do
        it 'returns :no_content status' do
          request
          expect(response).to have_http_status(:no_content)
        end

        it 'destroy variant' do
          expect { request }.to change(SmsPlan::Variant, :count).by(-1)
        end
      end

      context 'when variant with given id does not exist' do
        let(:variant_id) { 'non-existing' }

        it 'returns :not_found status' do
          request
          expect(response).to have_http_status(:not_found)
        end

        it 'does not create variant' do
          expect { request }.not_to change(SmsPlan::Variant, :count)
        end
      end

      context 'when intervention was published' do
        let(:intervention) { create(:intervention, :published) }
        let(:session) { create(:session, intervention: intervention) }

        it 'returns 405 status' do
          expect { request }.not_to change(SmsPlan, :count)
          expect(response).to have_http_status(:method_not_allowed)
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user without access for variant' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }

    it 'returns 404' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
