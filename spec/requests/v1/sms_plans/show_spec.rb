# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sms_plans/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_sms_plan_path(id: sms_plan_id), headers: headers }

  context 'when there is a sms plan with given id' do
    let!(:end_at) { Date.strptime('11/03/2021', '%d/%m/%Y') }
    let!(:sms_plan) { create(:sms_plan, end_at: end_at) }
    let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan, created_at: 2.days.ago) }
    let!(:variant2) { create(:sms_plan_variant, sms_plan: sms_plan, created_at: 1.day.ago) }
    let!(:sms_plan_id) { sms_plan.id }

    before do
      request
    end

    context 'team admin' do
      let(:user) { create(:user, :confirmed, :team_admin) }
      let!(:intervention) { create(:intervention, user: user) }
      let!(:session) { create(:session, intervention: intervention) }
      let!(:sms_plan) { create(:sms_plan, session: session) }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns sms plan with variant data' do
      expect(json_response['data']).to include(
        'id' => sms_plan_id.to_s,
        'type' => 'sms_plan',
        'attributes' => include('name' => sms_plan.name, 'end_at' => '11/03/2021')
      )
      expect(json_response['included']).to include(
        'id' => variant.id,
        'type' => 'variant',
        'attributes' => include(
          'formula_match' => variant.formula_match,
          'content' => variant.content
        )
      )
      expect(json_response['included']).to include(
        'id' => variant2.id,
        'type' => 'variant',
        'attributes' => include(
          'formula_match' => variant2.formula_match,
          'content' => variant2.content
        )
      )
    end

    it 'return in correct order' do
      expect(json_response['included'][0]['id']).to eq(variant.id)
      expect(json_response['included'][1]['id']).to eq(variant2.id)
    end

    context 'when given sms plan is an alert' do
      let!(:user) { create(:user, :confirmed, :admin) }
      let!(:intervention) { create(:intervention, user: user) }
      let!(:session) { create(:session, intervention: intervention) }
      let!(:sms_plan) { create(:sms_alert, session: session, phones: [phone]) }
      let!(:phone) { create(:phone, :confirmed) }
      let!(:sms_plan_id) { sms_plan.id }

      it 'returns sms alert plan with phone data' do
        request
        expect(json_response['included']).to include(
          'id' => phone.id.to_s, # id is an integer, returned id is a string...
          'type' => 'phone',
          'attributes' => include('iso' => phone.iso, 'number' => phone.number, 'prefix' => phone.prefix)
        )
      end
    end
  end

  context 'when there is no sms plan with given id' do
    let!(:sms_plan_id) { 'invalid id' }

    it 'has correct http code :not_found' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
