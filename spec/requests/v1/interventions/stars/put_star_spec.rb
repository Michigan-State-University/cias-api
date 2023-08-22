# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /v1/interventions/:id/star', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }

  let(:intervention) { create(:intervention, user: researcher) }

  let(:headers) { admin.create_new_auth_token }
  let(:request) { put make_starred_v1_intervention_path(intervention.id), headers: headers }

  context 'admin marks the intervention as starred' do
    before { request }

    it 'the admin sees the intervention as starred' do
      expect(intervention.starred_by?(admin.id)).to eq(true)
    end

    it 'the owner still does not see their intervention as starred' do
      expect(intervention.starred_by?(researcher.id)).to eq(false)
    end
  end

  it 'behaves idempotently' do
    expect { 10.times { request } }.to change(Star, :count).by(1)
  end
end
