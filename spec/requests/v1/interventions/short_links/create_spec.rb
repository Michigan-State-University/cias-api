# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/short_links', type: :request do
  let(:current_user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: current_user) }
  let(:params) do
    {
      short_links: [
        { name: 'example1' },
        { name: 'example2' }
      ]
    }
  end
  let(:request) do
    post v1_intervention_short_links_path(intervention.id), params: params, headers: current_user.create_new_auth_token
  end

  context 'when intervention doesn\'t have any short links' do
    before { request }

    it { expect(response).to have_http_status(:ok) }

    it 'create short links' do
      expect(intervention.reload.short_links.count).to be 2
    end

    it 'short links have correct name' do
      expect(json_response['data'].map { |short_link| short_link['attributes']['name'] }).to match(%w[example1 example2])
    end
  end

  context 'when intervention has short links' do
    let!(:short_links) { create_list(:short_link, 5, linkable: intervention) }

    before { request }

    it { expect(response).to have_http_status(:ok) }

    it 'create short links' do
      expect(intervention.reload.short_links.count).to be 2
    end

    it 'short links have correct name' do
      expect(json_response['data'].map { |short_link| short_link['attributes']['name'] }).to match(%w[example1 example2])
    end
  end

  context 'when name is already used' do
    let(:other_intervention) { create(:intervention) }
    let!(:short_link) { create(:short_link, linkable: other_intervention, name: 'example2') }
    let!(:short_links) { create_list(:short_link, 3, linkable: intervention) }

    before { request }

    it {
      expect(response).to have_http_status(:unprocessable_entity)
    }

    it {
      expect(json_response).to match({ 'message' => 'This intervention link has already been taken', 'details' => { 'taken_names' => ['example2'] } })
    }
  end

  context 'when current user is collaborator' do
    let(:intervention) { create(:intervention) }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: false) }
    let(:current_user) { collaborator.user }

    before { request }

    it {
      expect(response).to have_http_status(:forbidden)
    }
  end
end
