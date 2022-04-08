# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_plan/:id/clone', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:session) { create(:session) }
  let(:headers) { user.create_new_auth_token }
  let!(:sms_plan) { create(:sms_plan, name: 'Plan name', session: session) }
  let!(:variants) { create_list(:sms_plan_variant, 3, sms_plan: sms_plan, formula_match: 'test', content: 'content') }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post clone_v1_sms_plan_path(id: sms_plan.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      let(:request) { post clone_v1_sms_plan_path(id: sms_plan.id), headers: headers }

      it_behaves_like 'authorized user'
    end
  end

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when user clones a sms_plan' do
        before { post clone_v1_sms_plan_path(id: sms_plan.id), headers: headers }

        let(:cloned_sms_plan) { json_response['data']['attributes'] }

        it { expect(response).to have_http_status(:created) }

        it 'has correct name' do
          expect(cloned_sms_plan['name']).to eq 'Copy of Plan name'
        end

        it 'has correct type' do
          expect(cloned_sms_plan['type']).to eq 'SmsPlan::Normal'
        end

        context 'copied variants' do
          it 'have correct size' do
            expect(SmsPlan.find(json_response['data']['id']).variants.size).to eq variants.size
          end

          it 'have correct content' do
            expect(SmsPlan.find(json_response['data']['id']).variants.first.content).to eq 'content'
          end

          it 'have correct formula_match' do
            expect(SmsPlan.find(json_response['data']['id']).variants.first.formula_match).to eq 'test'
          end
        end

        context 'copied alert phones' do
          let!(:sms_plan) { create(:sms_alert, name: 'Plan name', session: session) }
          let!(:phone) { create(:phone, :confirmed, sms_plans: [sms_plan]) }

          before { post clone_v1_sms_plan_path(id: sms_plan.id), headers: headers }

          it 'has correct amount of alert phones' do
            expect(SmsPlan.find(json_response['data']['id']).alert_phones.size).to eq 1
          end

          it 'has correct phone number in alert phone data' do
            expect(SmsPlan.find(json_response['data']['id']).alert_phones.first.phone.id).to eq phone.id
          end
        end
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when user has multiple roles' do
      let(:user) { admin_with_multiple_roles }

      it_behaves_like 'permitted user'
    end
  end
end
