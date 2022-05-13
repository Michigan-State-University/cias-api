# frozen_string_literal: true

RSpec.describe 'PATCH /v1/sms_plans/:sms_plan_id/move_variants', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create(:sms_plan, session: session) }
  let!(:sms_variants) { create_list(:sms_plan_variant, 3, sms_plan: sms_plan) }

  let(:params) do
    {
      variant: {
        position: [
          { 'id' => sms_variants[0].id, 'position' => 2 },
          { 'id' => sms_variants[2].id, 'position' => 0 }
        ]
      }
    }
  end

  let(:request) do
    patch v1_sms_plan_move_variants_path(sms_plan_id: sms_plan.id), params: params, headers: user.create_new_auth_token
  end

  before { request }

  context 'when params correct' do
    it 'correctly reorders variants' do
      expected = sms_variants.map(&:reload).sort_by(&:position).pluck(:id)
      expect(json_response['included'].pluck('id')).to eq expected
    end
  end

  context 'when params invalid (wrong ID)' do
    let(:params) do
      {
        variant: {
          position: [
            {
              'id' => 'invalid-id', 'position' => 1
            },
            {
              'id' => 'id2', 'position' => 2
            }
          ]
        }
      }
    end

    it 'returns Not Found HTTP status code' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when params invalid (wrong request format)' do
    let(:params) do
      {
        position: []
      }
    end

    it 'returns Bad Request HTTP status code' do
      expect(response).to have_http_status(:bad_request)
    end
  end
end
