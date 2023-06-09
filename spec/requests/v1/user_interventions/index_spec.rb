# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_interventions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }

  let(:participant1) { create(:user, :confirmed, :participant) }
  let(:participant2) { create(:user, :confirmed, :participant) }

  let(:intervention) { create(:intervention, :published) }
  let!(:sessions) { create_list(:session, 5, intervention_id: intervention.id) }

  let!(:user_interventions1) { create(:user_intervention, intervention: intervention, user: participant1, status: 'completed') }
  let!(:user_interventions2) { create_list(:user_intervention, 3, intervention: intervention, user: participant2, status: 'in_progress') }

  let(:headers) { user.create_new_auth_token }
  let(:params) { {} }
  let(:request) { get v1_user_interventions_path, headers: headers, params: params }

  before do
    request
  end

  context 'when user is admin' do
    it 'return data has correct size' do
      expect(json_response['data'].size).to be(4)
    end

    it 'return correct data' do
      expect(json_response['data']).to include(
        {
          'id' => user_interventions2[0].id,
          'type' => 'user_intervention',
          'attributes' => {
            'blocked' => false,
            'completed_sessions' => 0,
            'status' => 'in_progress',
            'sessions_in_intervention' => 5,
            'last_answer_date' => nil,
            'contain_multiple_fill_session' => false,
            'intervention' => {
              'id' => intervention.id,
              'type' => intervention.type,
              'name' => intervention.name,
              'additional_text' => '',
              'image_alt' => nil,
              'logo_url' => nil,
              'files' => [],
              'live_chat_enabled' => false
            }
          }
        },
        {
          'id' => user_interventions2[1].id,
          'type' => 'user_intervention',
          'attributes' => {
            'blocked' => false,
            'completed_sessions' => 0,
            'status' => 'in_progress',
            'sessions_in_intervention' => 5,
            'last_answer_date' => nil,
            'contain_multiple_fill_session' => false,
            'intervention' => {
              'id' => intervention.id,
              'type' => intervention.type,
              'name' => intervention.name,
              'additional_text' => '',
              'image_alt' => nil,
              'logo_url' => nil,
              'files' => [],
              'live_chat_enabled' => false
            }
          }
        },
        {
          'id' => user_interventions2[2].id,
          'type' => 'user_intervention',
          'attributes' => {
            'blocked' => false,
            'completed_sessions' => 0,
            'status' => 'in_progress',
            'sessions_in_intervention' => 5,
            'last_answer_date' => nil,
            'contain_multiple_fill_session' => false,
            'intervention' => {
              'id' => intervention.id,
              'type' => intervention.type,
              'name' => intervention.name,
              'additional_text' => '',
              'image_alt' => nil,
              'logo_url' => nil,
              'files' => [],
              'live_chat_enabled' => false
            }
          }
        },
        {
          'id' => user_interventions1.id,
          'type' => 'user_intervention',
          'attributes' => {
            'blocked' => false,
            'completed_sessions' => 0,
            'status' => 'completed',
            'sessions_in_intervention' => 5,
            'last_answer_date' => nil,
            'contain_multiple_fill_session' => false,
            'intervention' => {
              'id' => intervention.id,
              'type' => intervention.type,
              'name' => intervention.name,
              'additional_text' => '',
              'image_alt' => nil,
              'logo_url' => nil,
              'files' => [],
              'live_chat_enabled' => false
            }
          }
        }
      )
    end

    context 'with multiple fill session' do
      let!(:sessions) { create(:session, :multiple_times, intervention_id: intervention.id) }

      it 'inform that intervention contains multiple fill session' do
        expect(json_response['data'][0]['attributes']).to include(
          {
            'blocked' => false,
            'completed_sessions' => 0,
            'last_answer_date' => nil,
            'contain_multiple_fill_session' => true,
            'sessions_in_intervention' => 1,
            'status' => 'in_progress',
            'intervention' => {
              'additional_text' => '',
              'files' => [],
              'id' => intervention.id,
              'image_alt' => nil,
              'live_chat_enabled' => false,
              'logo_url' => nil,
              'name' => intervention.name,
              'type' => 'Intervention'
            }
          }
        )
      end
    end

    context 'with pagination params' do
      let!(:params) { { start_index: 0, end_index: 1 } }

      it 'return data has correct size' do
        expect(json_response['data'].size).to be(2)
      end

      it 'return correct collection size' do
        expect(json_response['user_interventions_size']).to be(4)
      end
    end
  end

  context 'when user is participant should return only user_interventions belongs to him' do
    let(:user) { participant2 }

    it 'return correct data' do
      expect(json_response['data'].size).to be(3)
    end
  end

  context 'when intervention is closed or archived' do
    let(:user) { participant1 }

    let(:intervention_closed) { create(:intervention, :closed) }
    let(:intervention_archived) { create(:intervention, :archived) }
    let!(:user_interventions1) { create(:user_intervention, intervention: intervention, user: participant1, status: 'ready_to_start') }
    let!(:user_interventions2) { create(:user_intervention, intervention: intervention_closed, user: participant1, status: 'ready_to_start') }
    let!(:user_interventions3) { create(:user_intervention, intervention: intervention_archived, user: participant1, status: 'ready_to_start') }

    it 'return only interventions which have published status' do
      expect(json_response['data'].size).to be(1)
    end
  end
end
