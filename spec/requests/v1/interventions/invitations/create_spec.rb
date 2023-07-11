# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:flexible_order_intervention, status: intervention_status, user_id: user.id, shared_to: 'registered') }
  let!(:intervention_status) { :published }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let!(:invitation_email) { 'a@a.com' }
  let!(:params) do
    {
      intervention_invitation: {
        emails: [invitation_email, participant.email]
      }
    }
  end
  let(:request) { post v1_intervention_invitations_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  context 'create intervention invitation' do
    context 'when intervention is published' do
      before do
        request
      end

      it 'return correct http status' do
        expect(response).to have_http_status(:created)
      end

      it 'return correct response data' do
        expect(json_response['data'].size).to be(2)
      end

      it 'create correct intervention invitation' do
        expect(intervention.reload.invitations.map(&:email)).to match_array([invitation_email, participant.email])
      end
    end

    context 'when current user is collaborator' do
      let!(:intervention) { create(:flexible_order_intervention) }
      let!(:intervention_status) { :draft }
      let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: false) }
      let(:user) { collaborator.user }

      before { request }

      it {
        expect(response).to have_http_status(:forbidden)
      }
    end

    %w[draft closed archived].each do |status|
      context "when intervention is #{status}" do
        let!(:intervention_status) { status.to_sym }

        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:not_acceptable)
        end
      end
    end

    context 'when intervention has access for only invitated participants' do
      let!(:intervention) { create(:flexible_order_intervention, status: intervention_status, user_id: user.id, shared_to: 'invited') }

      before do
        request
      end

      it 'invited emails should be on the list with granted access to intervention' do
        expect(intervention.reload.intervention_accesses.map(&:email)).to match_array([invitation_email, participant.email])
      end
    end

    context 'when it is a non-module intervention' do
      let!(:intervention) { create(:intervention, user: user, status: 'published') }

      it 'returns correct HTTP status (Unprocessable Entity)' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
