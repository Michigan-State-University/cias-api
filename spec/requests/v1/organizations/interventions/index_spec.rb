# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:organization_id/interventions', type: :request do
  let(:organization1) { create(:organization) }
  let(:organization2) { create(:organization) }
  let(:user) { create(:user, :confirmed, :e_intervention_admin, organizable: organization1) }
  let!(:intervention_without_organization) { create(:intervention, user_id: user.id) }
  let!(:interventions_with_organization) { create_list(:intervention, 2, organization_id: organization1.id) }
  let!(:intervention_with_other_organization) { create(:intervention, organization_id: organization2.id) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organization_interventions_path(organization_id: organization1.id), params: params, headers: headers }
  let!(:params) { {} }

  shared_examples 'organization invitations' do |interventions_size|
    it { expect(response).to have_http_status(:ok) }

    it 'returns proper size of interventions of organization' do
      expect(json_response['interventions'].size).to eq interventions_size
    end
  end

  context 'when params are given' do
    let!(:params) { { page: 1, per_page: 1 } }

    before { request }

    it_behaves_like 'organization invitations', 1

    it 'returns one intervention of organization' do
      expect(json_response['interventions'][0]['id']).to eq interventions_with_organization.first.id
    end
  end

  context 'when params are not given' do
    before { request }

    it_behaves_like 'organization invitations', 2

    it 'returns all interventions of organization' do
      data = json_response['interventions']
      expect(data[0]['id']).to eq interventions_with_organization.first.id
      expect(data[1]['id']).to eq interventions_with_organization.last.id
    end
  end
end
