# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_links', type: :request do
  let(:sms_plan) { create(:sms_plan, no_formula_text: no_formula_text) }
  let(:request) { post v1_sms_links_path, params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:no_formula_text) { 'Test link: ::variable_1::' }

    context 'when url is without http' do
      let(:params) do
        {
          sms_link: {
            url: 'test.com',
            link_type: 'website',
            sms_plan_id: sms_plan.id,
            variable: 'variable_1'
          }
        }
      end

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates new sms link with proper data' do
        expect { request }.to change(SmsLink, :count).by(1)

        expect(SmsLink.last).to have_attributes(
          url: 'https://test.com',
          link_type: 'website',
          variable: 'variable_1',
          sms_plan_id: sms_plan.id,
          session_id: sms_plan.session.id
        )
      end
    end

    context 'when url is with http' do
      let(:params) do
        {
          sms_link: {
            url: 'http://test.com',
            link_type: 'website',
            sms_plan_id: sms_plan.id,
            variable: 'variable_1'
          }
        }
      end

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates new sms link with proper data' do
        expect { request }.to change(SmsLink, :count).by(1)

        expect(SmsLink.last).to have_attributes(
          url: 'http://test.com',
          link_type: 'website',
          variable: 'variable_1',
          sms_plan_id: sms_plan.id,
          session_id: sms_plan.session.id
        )
      end
    end

    context 'when variant_id is provided (formula variant link)' do
      let(:no_formula_text) { '' }
      let(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
      let(:params) do
        {
          sms_link: {
            url: 'https://test.com',
            link_type: 'website',
            variant_id: variant.id,
            variable: 'variable_1'
          }
        }
      end

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates sms link scoped to the variant' do
        expect { request }.to change(SmsLink, :count).by(1)

        expect(SmsLink.last).to have_attributes(
          variant_id: variant.id,
          sms_plan_id: sms_plan.id,
          session_id: sms_plan.session.id,
          variable: 'variable_1'
        )
      end

      it 'includes variant_id in the response' do
        request
        expect(json_response['data']['attributes']['variant_id']).to eq(variant.id)
      end
    end

    context 'when same variable name is used in two different variants' do
      let(:no_formula_text) { '' }
      let(:params) do
        {
          sms_link: {
            url: 'https://test.com',
            link_type: 'website',
            variant_id: variant_b.id,
            variable: 'shared_var'
          }
        }
      end
      let(:variant_a) { create(:sms_plan_variant, sms_plan: sms_plan) }
      let(:variant_b) { create(:sms_plan_variant, sms_plan: sms_plan) }

      before { create(:sms_link, variant: variant_a, sms_plan: sms_plan, session: sms_plan.session, variable: 'shared_var') }

      it 'returns :created status (no uniqueness collision across variants)' do
        request
        expect(response).to have_http_status(:created)
      end
    end

    context 'when same variable name is used in no-formula and a variant' do
      let(:no_formula_text) { 'Test: ::shared_var::' }
      let(:params) do
        {
          sms_link: {
            url: 'https://test.com',
            link_type: 'website',
            variant_id: variant.id,
            variable: 'shared_var'
          }
        }
      end
      let(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }

      before { create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, variable: 'shared_var') }

      it 'returns :created status (no collision between no-formula and variant scopes)' do
        request
        expect(response).to have_http_status(:created)
      end
    end
  end

  context 'when params are invalid' do
    let(:no_formula_text) { 'Test link: ::variable_1::' }
    let(:params) do
      {
        sms_link: {
          link_type: 'website',
          sms_plan_id: sms_plan.id,
          variable: 'variable_1'
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does NOT create SMS link' do
      expect { request }.not_to change(SmsLink, :count)
    end

    context 'when same variable is used twice in the same variant' do
      let(:no_formula_text) { '' }
      let(:params) do
        {
          sms_link: {
            url: 'https://test.com',
            link_type: 'website',
            variant_id: variant.id,
            variable: 'dup_var'
          }
        }
      end
      let(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }

      before { create(:sms_link, variant: variant, sms_plan: sms_plan, session: sms_plan.session, variable: 'dup_var') }

      it 'returns :unprocessable_entity' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does NOT create SMS link' do
        expect { request }.not_to change(SmsLink, :count)
      end
    end
  end
end
