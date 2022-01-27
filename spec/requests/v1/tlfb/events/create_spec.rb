# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/tlfb/events', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:intervention) { create(:intervention, status: status) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:tlfb_group, session: session) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:headers) { participant.create_new_auth_token }
  let!(:user_session) { create(:user_session, user: participant, session_id: session.id) }

  let(:params) do
    {
      event: {
        exact_date: DateTime.now,
        user_session_id: user_session.id,
        question_group_id: question_group.id
      }
    }
  end

  context 'when params are valid' do
    let(:request) do
      post v1_tlfb_events_path, params: params, headers: headers, as: :json
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'return correct data' do
      request
      expect(json_response['data']).to include(
        'type' => 'event',
        'attributes' => include(
          'name' => ''
        )
      )
    end

    it 'create event' do
      expect { request }.to change(Tlfb::Event, :count).by(1)
    end
  end

  context 'unauthorize user' do
    let(:request) do
      post v1_tlfb_events_path, params: params, as: :json
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when user has not permission to create an event' do
    let(:request) do
      post v1_tlfb_events_path, params: params, headers: headers, as: :json
    end

    %i[e_intervention_admin health_clinic_admin health_system_admin organization_admin researcher team_admin third_party].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it 'return correct status and error msg' do
          request
          expect(response).to have_http_status(:forbidden)
          expect(json_response['message']).to eq 'You are not authorized to access this page.'
        end
      end
    end
  end
end
