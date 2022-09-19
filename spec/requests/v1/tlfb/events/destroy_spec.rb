# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/tlfb/events', type: :request do
  let(:intervention) { create(:intervention, status: status) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:tlfb_group, session: session) }
  let!(:user_session) { create(:user_session, user: participant, session_id: session.id) }
  let(:day) { create(:tlfb_day, question_group: question_group, user_session: user_session) }
  let(:event) { create(:tlfb_event, day: day) }
  let(:participant) { create(:user, :confirmed, :participant) }

  let(:headers) { participant.create_new_auth_token }

  let(:request) { delete v1_tlfb_event_path(id: event.id), headers: headers }

  context 'when user can delete teh event' do
    it 'return correct data' do
      request
      expect(response).to have_http_status(:no_content)
    end
  end

  context 'when user has no access' do
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

  context 'when other participant want to edit the event' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }

    it 'return correct status and error msg' do
      request
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include('Couldn\'t find Tlfb::Event with')
    end
  end

  context 'when id is wrong' do
    let(:request) { patch v1_tlfb_event_path(id: 'wrong_id'), headers: headers }

    it 'return correct status and error msg' do
      request
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include('Couldn\'t find Tlfb::Event with')
    end
  end
end
