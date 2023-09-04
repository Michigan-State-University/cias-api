# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/predefined_participants/:id', type: :request do
  let(:request) do
    patch v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user.id), params: params, headers: current_user.create_new_auth_token
  end
  let!(:intervention) { create(:intervention, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let(:user) { create(:user, :predefined_participant, :with_phone) }
  let(:params) do
    {
      predefined_user: {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name
      }
    }
  end

  it 'return correct status' do
    request
    expect(response).to have_http_status(:ok)
  end

  it 'return correct body' do
    request
    require 'pry'; binding.pry
    expect(json_response['data']['attributes'].keys).to match_array(%w[full_name first_name last_name phone slug health_clinic_id])
  end

  context 'other researcher' do
    let(:other_researcher) { create(:user, :researcher, :confirmed) }
    let(:current_user) { other_researcher }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'other role' do
    let(:other_user) { create(:user, :participant, :confirmed) }
    let(:current_user) { other_user }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end
