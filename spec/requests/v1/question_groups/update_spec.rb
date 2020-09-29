# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/interventions/:intervention_id/question_groups/:id', type: :request do
  let(:request) { patch v1_intervention_question_group_path(intervention_id: intervention.id, id: question_group.id), params: params, headers: headers }
  let(:params) do
    {
      question_group: {
        title: 'New Title'
      }
    }
  end

  let!(:intervention)   { create(:intervention, problem: create(:problem, :published)) }
  let!(:question_group) { create(:question_group, title: 'Old Title', intervention: intervention) }

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns forbidden status' do
      request

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    context 'when new title is provided in params' do
      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['title']).to eq 'New Title'
      end
    end

    context 'when new intervention_id is provided in params' do
      let!(:new_intevention) { create(:intervention) }
      let(:params) do
        {
          question_group: {
            intervention_id: new_intevention.id
          }
        }
      end

      it 'returns serialized question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['intervention_id']).to eq new_intevention.id
      end
    end
  end
end
