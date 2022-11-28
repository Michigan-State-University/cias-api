# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/import', type: :request do
  let!(:user) { create(:user, :admin, :confirmed) }
  let(:request) { post v1_import_intervention_path, params: params, headers: user.create_new_auth_token }
  let(:params) do
    {
      imported_file: {
        file: FactoryHelpers.upload_file('spec/factories/json/test_intervention.json', 'application/json', false)
      }
    }
  end

  context 'correctly import intervention' do
    before do
      request
    end

    it 'returns correct status' do
      expect(response).to have_http_status(:created)
    end

    skip 'increase Intervention count' do
      expect { request }.to change(Intervention, :count).by 1
    end
  end

  context 'incorrect params' do
    let(:params) do
      {
        imported_file: {
          file: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
        }
      }
    end

    before do
      request
    end

    it 'returns correct status' do
      expect(response).to have_http_status(:bad_request)
    end
  end
end
