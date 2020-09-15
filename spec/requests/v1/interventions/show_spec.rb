# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/problems/:problem_id/interventions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:problem) { create(:problem) }
  let(:intervention) { create(:intervention, problem_id: problem.id) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_problem_intervention_path(problem_id: problem.id, id: intervention.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_problem_intervention_path(problem_id: problem.id, id: intervention.id), headers: headers }

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
        get v1_problem_intervention_path(problem_id: problem.id, id: intervention.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        get v1_problem_intervention_path(problem_id: problem.id, id: intervention.id), headers: headers
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key intervention' do
        expect(json_response['data']['type']).to eq('intervention')
      end
    end
  end
end
