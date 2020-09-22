# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/questions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:question) { create(:question_analogue_scale, intervention_id: intervention.id) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is success' do
      before do
        delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:no_content) }
    end
  end
end
