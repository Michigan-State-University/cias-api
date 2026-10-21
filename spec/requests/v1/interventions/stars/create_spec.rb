# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/star', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }

  let(:intervention) { create(:intervention, user: researcher) }

  let(:headers) { admin.create_new_auth_token }
  let(:request) { post v1_intervention_create_star_path(intervention.id), headers: headers }

  context 'admin marks the intervention as starred' do
    before { request }

    it 'the admin sees the intervention as starred' do
      expect(intervention.starred_by?(admin.id)).to be(true)
    end

    it 'the owner still does not see their intervention as starred' do
      expect(intervention.starred_by?(researcher.id)).to be(false)
    end
  end

  context 'when the id in the request is of an intervention that does not exist' do
    let(:request) { post v1_intervention_create_star_path(SecureRandom.uuid), headers: headers }

    it 'returns the status not found' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the researcher does not have access to the intervention' do
    let!(:intervention) { create(:intervention) }
    let(:headers) { researcher.create_new_auth_token }

    it 'returns the status not found' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when a participant wants to star an intervention' do
    let!(:intervention) { create(:intervention, shared_to: :anyone) }
    let(:participant) { create(:user, :participant) }
    let(:headers) { participant.create_new_auth_token }

    it 'returns the status forbidden' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'behaves idempotently' do
    expect { 10.times { request } }.to change(Star, :count).by(1)
  end

  it 'answers 204, also when starred again' do
    2.times do
      request
      expect(response).to have_http_status(:no_content)
    end
  end

  context 'when intervention serializers are cached in Redis' do
    include_context 'with intervention serializers cached in Redis', [V1::InterventionSerializer, V1::SimpleInterventionSerializer]

    before { intervention }

    def starred_on_show(user)
      get v1_intervention_path(intervention.id), headers: user.create_new_auth_token
      expect(response).to have_http_status(:ok)
      json_response['data']['attributes']['starred']
    end

    it 'shows the star on the dashboard list of the starring user only' do
      request

      expect(starred_on_list(admin)).to be(true)
      expect(starred_on_list(researcher)).to be(false)
    end

    it 'shows starred: true on an already loaded intervention page' do
      pending 'BUG: starring does not expire the cached InterventionSerializer entry, so a page loaded before starring keeps starred: false (T-12)'
      expect(starred_on_show(admin)).to be(false)

      request

      expect(starred_on_show(admin)).to be(true)
    end

    it 'does not show the star to another user on the intervention page' do
      pending 'BUG: the InterventionSerializer cache key does not include the user, so another user gets the starring user\'s starred: true (T-12)'
      request
      expect(starred_on_show(admin)).to be(true)

      expect(starred_on_show(researcher)).to be(false)
    end

    it 'shows starred: true on an already loaded dashboard list' do
      pending 'BUG: starring does not expire the cached SimpleInterventionSerializer entry of the starring user, so the list keeps starred: false (T-12)'
      expect(starred_on_list(admin)).to be(false)

      request

      expect(starred_on_list(admin)).to be(true)
    end
  end
end
