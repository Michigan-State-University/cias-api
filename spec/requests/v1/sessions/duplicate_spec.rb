# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/intervention/:intervention_id/sessions/:id/duplicate', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user) }
  let!(:intervention_2) { create(:intervention, user: user) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
  let!(:questions) { create_list(:question_single, 3, question_group: question_group) }
  let!(:params) do
    {
      new_intervention_id: intervention_2.id
    }
  end
  let!(:headers) { user.create_new_auth_token }
  let!(:request) { post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      before { post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { request }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end

      it 'session is duplicated' do
        expect(json_response['data']['attributes']).to include(
          'intervention_id' => intervention_2.id,
          'position' => session.position,
          'name' => session.name,
          'schedule' => session.schedule,
          'schedule_payload' => session.schedule_payload
        )
      end

      it 'question_group is duplicated' do
        expect(Session.find(json_response['data']['id']).question_groups.first).not_to eq(nil)
      end

      it 'question_group duplicated has diffrent id from original' do
        expect(Session.find(json_response['data']['id']).question_groups.first.title).to eq(question_group.title)
      end

      it 'questions are duplicated' do
        expect(Session.find(json_response['data']['id']).question_groups.first.questions.size).to eq(3)
      end

      it 'question duplicated has diffrent id from original' do
        expect(Session.find(json_response['data']['id']).question_groups.first.questions.first.title).to eq(questions.first.title)
      end
    end
  end

  context 'when intervention_id is invalid' do
    before do
      post v1_intervention_duplicate_session_path(intervention_id: 9000, id: session.id), params: params, headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when session_id is invalid' do
    before do
      post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: 9000), params: params, headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when params are invalid' do
    let(:params) do
      {
        new_intervention_id: 9999
      }
    end

    before do
      post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when all params are valid and response' do
    context 'is success' do
      before do
        post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:created) }

      it 'session is duplicated' do
        expect(json_response['data']['attributes']).to include(
          'intervention_id' => intervention_2.id,
          'position' => session.position,
          'name' => session.name,
          'schedule' => session.schedule,
          'schedule_payload' => session.schedule_payload
        )
      end

      it 'question_group is duplicated' do
        expect(Session.find(json_response['data']['id']).question_groups.first).not_to eq(nil)
      end

      it 'question_group duplicated has diffrent id from original' do
        expect(Session.find(json_response['data']['id']).question_groups.first.title).to eq(question_group.title)
      end

      it 'questions are duplicated' do
        expect(Session.find(json_response['data']['id']).question_groups.first.questions.size).to eq(3)
      end

      it 'question duplicated has diffrent id from original' do
        expect(Session.find(json_response['data']['id']).question_groups.first.questions.first.title).to eq(questions.first.title)
      end
    end
  end
end
