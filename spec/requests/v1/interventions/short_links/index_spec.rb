# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/short_links', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:other_user) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention, user: researcher) }
  let(:other_intervention) { create(:intervention, user: other_user) }
  let!(:short_links) { create_list(:short_link, 4, linkable: intervention) }
  let!(:other_short_links) { create_list(:short_link, 2, linkable: other_intervention) }
  let(:intervention_id) { intervention.id }
  let(:current_user) { researcher }
  let(:request) do
    get v1_intervention_short_links_path(intervention_id), headers: current_user.create_new_auth_token
  end

  before do
    request
  end

  context 'when current_user is researcher' do
    it { expect(response).to have_http_status(:ok) }

    it 'JSON response contains proper attributes' do
      expect(json_response['data'].first.symbolize_keys).to include(:id, :type, :attributes)
      expect(json_response['data'].first['attributes'].symbolize_keys.keys).to contain_exactly(:name, :health_clinic_id)
    end

    it 'return correct number of links' do
      expect(json_response['data'].size).to eq 4
    end

    it 'return empty health clinics param' do
      expect(json_response['health_clinics']).to be nil
    end
  end

  context 'when current_user is participant' do
    let(:current_user) { create(:user, :confirmed, :participant) }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context 'when intervention is in organization' do
    let(:organization) { create(:organization, :with_health_clinics) }
    let(:intervention) { create(:intervention, user: researcher, organization: organization) }

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response).to include('data', 'health_clinics')
    }

    it {
      expect(json_response['health_clinics'].size).to eq 3
    }
  end
end
