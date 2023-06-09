# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/sms_plans/:sms_plan_id/variants/:id', type: :request do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
  let!(:variant_id) { variant.id }
  let(:request) do
    patch v1_sms_plan_variant_path(sms_plan_id: sms_plan.id, id: variant_id), params: params, headers: headers
  end

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
  let(:params) do
    {
      variant: {
        formula_match: '> 3'
      }
    }
  end

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'valid params' do
        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'updates variant attributes' do
          expect { request }.to change { variant.reload.formula_match }.from(variant.formula_match).to('> 3').and \
            avoid_changing { SmsPlan::Variant.count }
        end
      end

      context 'invalid params' do
        let(:params) { { variant: {} } }

        it 'returns :bad_request status' do
          request
          expect(response).to have_http_status(:bad_request)
        end

        it 'does not update variant attributes' do
          expect { request }.not_to change(variant, :formula_match)
        end
      end

      context 'when intervention was published' do
        let(:intervention) { create(:intervention, :published) }
        let(:session) { create(:session, intervention: intervention) }
        let(:params) do
          {
            variant: {
              formula_match: '> 3'
            }
          }
        end

        it 'returns 405 status' do
          expect { request }.not_to change(variant, :formula_match)
          expect(response).to have_http_status(:method_not_allowed)
        end
      end

      context 'pass a image to the variant' do
        let(:params) do
          {
            variant: {
              attachment: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
            }
          }
        end

        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'attach image to the variant' do
          request
          expect(variant.reload.attachment.attached?).to be(true)
        end

        it 'returned data have correct format' do
          request
          expect(json_response['data']['attributes']['attachment'].keys).to match_array(%w[id name url created_at])
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
    let(:params) { {} }

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
