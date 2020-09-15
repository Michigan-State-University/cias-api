# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/problems/:problem_id/interventions/:id/invite', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:params) do
    {
      intervention: {
        emails: %w[some@email.com other_email@email.com]
      }
    }
  end

  let(:problem_user) { admin }
  let(:problem) { create(:problem, user: problem_user) }
  let(:intervention) { create(:intervention, problem_id: problem.id, emails: ['first@email.com']) }
  let(:problem_id) { problem.id }
  let(:intervention_id) { intervention.id }

  context 'when user has role admin' do
    before { post invite_v1_problem_intervention_path(problem_id: problem_id, id: intervention_id), params: params, headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it 'response contains proper attributes' do
      expect(json_response['data']['attributes']).to include(
        'emails' => match_array(%w[first@email.com some@email.com other_email@email.com]),
        'name' => intervention.name
      )
    end

    it 'updates a list of emails belonging to intervention' do
      expect(intervention.reload.emails).to match_array(%w[first@email.com some@email.com other_email@email.com])
    end

    it 'schedules an invitation job' do
      expect(InvitationJob::Participant::Intervention).to have_been_enqueued.exactly(:once)
                                                            .with(%w[some@email.com other_email@email.com], intervention_id)
    end
  end

  context 'when user has role researcher' do
    let(:user) { researcher }

    before { post invite_v1_problem_intervention_path(problem_id: problem_id, id: intervention_id), params: params, headers: headers }

    context 'problem does not belong to him' do
      it { expect(response).to have_http_status(:not_found) }
    end

    context 'problem belongs to him' do
      let(:problem_user) { researcher }

      it { expect(response).to have_http_status(:ok) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'emails' => match_array(%w[first@email.com some@email.com other_email@email.com]),
          'name' => intervention.name
        )
      end

      it 'updates a list of emails belonging to intervention' do
        expect(intervention.reload.emails).to match_array(%w[first@email.com some@email.com other_email@email.com])
      end

      it 'schedules an invitation job' do
        expect(InvitationJob::Participant::Intervention).to have_been_enqueued.exactly(:once)
                                                              .with(%w[some@email.com other_email@email.com], intervention_id)
      end
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    before { post invite_v1_problem_intervention_path(problem_id: problem_id, id: intervention_id), params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context 'when user has role guest' do
    let(:user) { guest }

    before { post invite_v1_problem_intervention_path(problem_id: problem_id, id: intervention_id), params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end
end
