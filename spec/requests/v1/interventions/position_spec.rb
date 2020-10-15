# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/problems/:problem_id/interventions/position', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:problem) { create(:problem, user: user) }
  let(:intervention_1) { create(:intervention, position: 4, problem: problem) }
  let(:intervention_2) { create(:intervention, position: 5, problem: problem) }
  let(:intervention_3) { create(:intervention, position: 6, problem: problem) }
  let(:params) do
    {
      intervention: {
        position: [
          {
            id: intervention_1.id,
            position: 11
          },
          {
            id: intervention_2.id,
            position: 22
          },
          {
            id: intervention_3.id,
            position: 33
          }
        ]
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_problem_interventions_position_path(problem_id: problem.id), params: params }

      it 'response contains generated uid token' do
        request

        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { patch v1_problem_interventions_position_path(problem_id: problem.id), params: params, headers: user.create_new_auth_token }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        patch v1_problem_interventions_position_path(problem_id: problem.id), params: params, headers: user.create_new_auth_token
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        patch v1_problem_interventions_position_path(problem_id: problem.id), params: params, headers: user.create_new_auth_token
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'proper order' do
        positions = json_response['interventions'].map { |intervention| intervention['position'] }
        expect(positions).to eq [11, 22, 33]
      end
    end
  end
end
