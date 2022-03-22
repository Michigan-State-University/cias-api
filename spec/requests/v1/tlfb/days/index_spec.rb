# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/calendar_data', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:intervention) { create(:intervention, status: status) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:tlfb_group, session: session) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:headers) { participant.create_new_auth_token }
  let!(:user_session) { create(:user_session, user: participant, session_id: session.id) }
  let!(:day1) { create(:tlfb_day, user_session: user_session, question_group: question_group) }
  let!(:day2) { create(:tlfb_day, user_session: user_session, question_group: question_group) }
  let!(:events1) do
    create_list(:tlfb_event, 2, day: day1)
  end
  let!(:events2) do
    create_list(:tlfb_event, 3, day: day1)
  end
  let!(:consumption_result) { create(:tlfb_consumption_result, day: day1) }
  let(:params) { { user_session_id: user_session.id, tlfb_group_id: question_group.id } }

  let(:request) do
    get v1_calendar_data_path, headers: headers, params: params
  end

  before do
    request
  end

  context 'when params are valid' do
    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data' do
      expect(json_response['data'].count).to be(2)
      expect(json_response['data'].pluck('id')).to include(day1.id.to_s, day2.id.to_s)
      expect(json_response['included'].size).to eq 6
      expect(json_response['included'].pluck('type').uniq).to include('event', 'consumption_result')
    end
  end

  context 'when user has no permission to user_session' do
    let(:other_participant) { create(:user, :confirmed, :participant) }
    let(:headers) { other_participant.create_new_auth_token }

    it 'return empty json' do
      expect(json_response['data']).to eq []
      expect(json_response['included']).to eq []
    end
  end
end
