# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/star', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }

  let(:intervention) { create(:intervention, user: researcher) }
  let(:other_intervention) { create(:intervention, user: researcher) }

  let(:headers) { admin.create_new_auth_token }
  let(:request) { delete v1_intervention_create_star_path(intervention.id), headers: headers }

  before do
    Star.create(user_id: admin.id, intervention_id: intervention.id)
    Star.create(user_id: researcher.id, intervention_id: intervention.id)
    Star.create(user_id: admin.id, intervention_id: other_intervention.id)
    Star.create(user_id: researcher.id, intervention_id: other_intervention.id)
  end

  context 'admin unstars the intervention' do
    before { request }

    it 'the admin sees the intervention as not starred' do
      expect(intervention.starred_by?(admin.id)).to eq(false)
    end

    it 'the owner still does see their intervention as starred' do
      expect(intervention.starred_by?(researcher.id)).to eq(true)
    end
  end

  context 'when the id in the request is of an intervention that does not exist' do
    let(:request) { delete v1_intervention_create_star_path(SecureRandom.uuid), headers: headers }

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

  it 'deletes only one star' do
    expect { request }.to change(Star, :count).by(-1)
  end
end
