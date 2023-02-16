# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/verify_short_link', type: :request do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, :published, user: researcher) }
  let!(:short_link) { create(:short_link, linkable: intervention, name: 'short-link') }
  let(:params) { { name: 'short-link' } }
  let(:request) do
    get v1_verify_short_links_path, params: params, headers: participant.create_new_auth_token
  end

  context 'sequential intervention with sessions' do
    let!(:session) { create(:session, intervention: intervention) }

    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                health_clinic_id: nil,
                                                                type: 'Intervention',
                                                                first_session_id: session.id
                                                              })
    }
  end

  context 'sequential intervention without sessions' do
    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                health_clinic_id: nil,
                                                                type: 'Intervention',
                                                                first_session_id: nil
                                                              })
    }
  end

  context 'sequential module intervention with sessions' do
    let(:intervention) { create(:flexible_order_intervention, :published, user: researcher) }
    let!(:session) { create(:session, intervention: intervention) }

    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                health_clinic_id: nil,
                                                                type: 'Intervention::FlexibleOrder',
                                                                first_session_id: nil
                                                              })
    }
  end
end
