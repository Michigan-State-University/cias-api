# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/test_link', type: :request do
  let_it_be(:admin) { create(:user, :confirmed, :admin) }
  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:other_researcher) { create(:user, :confirmed, :researcher) }
  let_it_be(:participant) { create(:user, :confirmed, :participant) }

  let(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let(:user) { researcher }
  let(:headers) { user.create_new_auth_token }

  # A plain method rather than a memoised `let`: naming it `request` would shadow
  # `ActionDispatch::Integration::Session#request`, which the rest of this repo's request
  # specs rely on.
  def perform_request
    post test_link_v1_intervention_path(id: intervention.id), headers: headers
  end

  context 'when the researcher owns the intervention' do
    before { perform_request }

    it { expect(response).to have_http_status(:created) }

    it 'returns a token bound to that intervention' do
      attributes = json_response['data']['attributes']

      expect(attributes['token']).to be_present
      expect(attributes['intervention_id']).to eq(intervention.id)
      expect(V1::TestRuns::LinkToken.verify(attributes['token'], intervention.id)).to be_present
    end

    it 'signs the minting researcher into the token' do
      payload = V1::TestRuns::LinkToken.verify(json_response['data']['attributes']['token'], intervention.id)

      expect(payload['minted_by_id']).to eq(researcher.id)
    end

    it 'returns an expiry within the configured TTL' do
      expires_at = Time.zone.parse(json_response['data']['attributes']['expires_at'])

      expect(expires_at).to be_within(1.minute).of(V1::TestRuns::LinkToken.ttl.from_now)
    end

    it 'returns a token that is useless for another intervention' do
      other = create(:intervention, user: researcher)

      expect(V1::TestRuns::LinkToken.verify(json_response['data']['attributes']['token'], other.id)).to be_nil
    end

    it 'mints a fresh token on every call' do
      first_token = json_response['data']['attributes']['token']
      post test_link_v1_intervention_path(id: intervention.id), headers: headers

      expect(json_response['data']['attributes']['token']).not_to eq(first_token)
    end
  end

  context 'when the requester is an admin' do
    let(:user) { admin }

    it 'mints a token' do
      perform_request

      expect(response).to have_http_status(:created)
      expect(json_response['data']['attributes']['token']).to be_present
    end
  end

  context 'when the requester is a participant' do
    let(:user) { participant }

    it 'is forbidden' do
      perform_request

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when the requester is a researcher who cannot reach the intervention' do
    let(:user) { other_researcher }

    it 'is not found' do
      perform_request

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the request is unauthenticated' do
    let(:headers) { {} }

    it 'is unauthorized' do
      perform_request

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
