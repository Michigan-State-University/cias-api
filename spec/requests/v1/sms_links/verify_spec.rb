# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_links', type: :request do
  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create(:sms_plan, no_formula_text: no_formula_text, session: session) }
  let(:sms_link) { create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, link_type: link_type, variable: 'variable_1') }
  let(:sms_links_user) { create(:sms_links_user, sms_link: sms_link, user: user) }
  let(:request) { post v1_verify_sms_link_path, params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:no_formula_text) { 'Test link: ::variable_1::' }
    let(:params) do
      {
        slug: sms_links_user.slug
      }
    end

    context 'when link_type is website' do
      let(:link_type) { 'website' }

      it 'returns status :ok' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'recieves proper attributes' do
        request
        expect(json_response).to eq({ 'link_type' => 'website', 'redirect_url' => sms_link.url })
      end
    end

    context 'when link_type is video' do
      let(:link_type) { 'video' }

      it 'returns status :ok' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'recieves proper attributes' do
        request
        expect(json_response).to eq({ 'link_type' => 'video', 'redirect_url' => sms_link.url })
      end
    end
  end
end
