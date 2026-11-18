# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sms_links', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: researcher) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create(:sms_plan, session: session) }
  let!(:sms_link) do
    create(:sms_link, sms_plan: sms_plan, session: session, url: 'https://first.com', link_type: 'website', variable: 'link_1')
  end
  let!(:other_sms_link) do
    create(:sms_link, sms_plan: sms_plan, session: session, url: 'https://second.com', link_type: 'video', variable: 'link_2')
  end
  let!(:foreign_sms_link) { create(:sms_link) }

  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:params) { { sms_link: { sms_plan_id: sms_plan.id } } }
  let(:request) { get v1_sms_links_path, params: params, headers: headers }

  context 'when user is not authenticated' do
    let(:headers) { {} }

    it_behaves_like 'unauthorized user'
  end

  context 'when user is an admin' do
    before { request }

    it 'returns :ok status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns only sms links of the given sms plan' do
      expect(json_response['data'].pluck('id')).to contain_exactly(sms_link.id, other_sms_link.id)
    end

    it 'returns sms links with proper attributes' do
      link_data = json_response['data'].find { |item| item['id'] == sms_link.id }

      expect(link_data['type']).to eq('sms_link')
      expect(link_data['attributes']).to include(
        'session_id' => session.id,
        'sms_plan_id' => sms_plan.id,
        'url' => 'https://first.com',
        'link_type' => 'website',
        'variable' => 'link_1'
      )
    end
  end

  context 'when user is the researcher who owns the intervention' do
    let(:user) { researcher }

    it 'returns :ok status with sms links of the plan' do
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to contain_exactly(sms_link.id, other_sms_link.id)
    end
  end

  context 'when sms plan has no sms links' do
    let(:params) { { sms_link: { sms_plan_id: create(:sms_plan, session: session).id } } }

    it 'returns an empty collection' do
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end
  end

  context 'when user is a researcher without access to the sms plan' do
    let(:user) { create(:user, :confirmed, :researcher) }

    it 'returns :forbidden status' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when user is a participant' do
    let(:user) { create(:user, :confirmed, :participant) }

    it 'returns :forbidden status' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when sms plan does not exist' do
    let(:params) { { sms_link: { sms_plan_id: 'non-existing-id' } } }

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when sms_plan_id param is missing' do
    let(:params) { {} }

    it 'returns :bad_request status' do
      request
      expect(response).to have_http_status(:bad_request)
    end
  end
end
