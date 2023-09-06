# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/predefined_participants', type: :request do
  let!(:intervention) { create(:intervention, :with_predefined_participants, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let(:request) do
    get v1_intervention_predefined_participants_path(intervention_id: intervention.id), headers: current_user.create_new_auth_token
  end

  it 'return correct status' do
    request
    expect(response).to have_http_status(:ok)
  end

  it 'return correct body' do
    request
    expect(json_response['data'].size).to eql(intervention.predefined_users.size)
  end

  it 'the element from array has correct keys' do
    request
    expect(json_response['data'].first['attributes'].keys).to match_array(%w[full_name first_name last_name phone slug health_clinic_id auto_invitation
                                                                             invitation_sent_at])
  end

  it_behaves_like 'users without access'
end
