# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:session_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention, status: intervention_status, user_id: user.id) }
  let!(:intervention_status) { :published }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let!(:invitation_email) { 'a@a.com' }
  let!(:params) do
    {
      session_invitation: {
        emails: [invitation_email, participant.email]
      }
    }
  end
  let(:request) { post v1_session_invitations_path(session_id: session.id), params: params, headers: user.create_new_auth_token }

  context 'create session invitation' do
    context 'when intervention is published' do
      before do
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:created)
      end

      it 'returns correct response data' do
        expect(json_response['invitations'].size).to be(2)
      end

      it 'creates correct session invites' do
        expect(session.reload.invitations.map(&:email)).to match_array([invitation_email, participant.email])
      end
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
  end
end
