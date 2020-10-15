# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/interventions/:intervention_id/question_groups/position', type: :request do
  let(:user) { create(:user, :researcher) }
  let!(:intervention)     { create(:intervention, problem: create(:problem, user: user)) }
  let!(:question_group_1) { create(:question_group, intervention: intervention, position: 3) }
  let!(:question_group_2) { create(:question_group, intervention: intervention, position: 4) }
  let!(:question_group_3) { create(:question_group, intervention: intervention, position: 5) }
  let(:request) { patch position_v1_intervention_question_groups_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  let(:params) do
    {
      question_group: {
        position: [
          {
            id: question_group_1.id,
            position: 6
          },
          {
            id: question_group_2.id,
            position: 7
          },
          {
            id: question_group_3.id,
            position: 8
          }
        ]
      }
    }
  end

  context 'when authenticated as admin user' do
    context 'when question group does not have questions' do
      it 'returns serialized cloned question_group' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['question_groups'].size).to eq 4
        expect(question_group_1.reload.position).to eq 6
        expect(question_group_2.reload.position).to eq 7
        expect(question_group_3.reload.position).to eq 8
      end
    end
  end
end
