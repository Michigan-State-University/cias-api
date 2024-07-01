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
  end
end
