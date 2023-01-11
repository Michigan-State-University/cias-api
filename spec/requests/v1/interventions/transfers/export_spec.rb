# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/export', type: :request do
  let!(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:intervention) }
  let(:request) { post v1_export_intervention_path(intervention.id), headers: user.create_new_auth_token }

  context 'export intervention' do
    before do
      request
    end

    it 'returns correct status' do
      expect(response).to have_http_status(:ok)
    end

    skip 'sends mail' do
      expect { request }.to change(ActionMailer::Base.deliveries, :count).by 1
    end
  end
end
