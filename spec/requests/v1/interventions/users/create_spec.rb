# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/users', type: :request do
  let!(:user) { create(:user, :confirmed, :admin) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention, user_id: user.id, status: intervention_status) }
  let!(:intervention_status) { :published }
  let!(:new_user_email) { 'a@a.com' }
  let!(:params) do
    {
      user_session: {
        emails: [participant.email, new_user_email]
      }
    }
  end

  let(:request) { post v1_intervention_invitations_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  context 'create user access' do
    %w[draft published].each do |status|
      context "when intervention status is #{status}" do
        let!(:intervention_status) { status.to_sym }

        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns correct response size' do
          expect(json_response['user_sessions'].size).to eq 2
        end

        it 'returns correct email addresses' do
          expect(json_response['user_sessions'].pluck('email')).to match_array([participant.email, new_user_email])
        end

        it 'does not create user account' do
          expect(User.find_by(email: new_user_email)).to be nil
        end

        it 'set intervention invitation size correctly' do
          expect(intervention.reload.invitations.size).to eq(2)
        end
      end
    end
  end

  context 'does not create intervention invitation when' do
    %w[closed archived].each do |status|
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
