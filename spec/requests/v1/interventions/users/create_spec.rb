# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/access', type: :request do
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

  let(:request) do
    post v1_intervention_accesses_path(intervention_id: intervention.id), params: params,
                                                                          headers: user.create_new_auth_token
  end

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
          expect(json_response['data'].size).to eq 2
        end

        it 'returns correct email addresses' do
          emails = json_response['data'].map { |invitation| invitation['attributes']['email'] }
          expect(emails).to contain_exactly(participant.email, new_user_email)
        end

        it 'does not create user account' do
          expect(User.find_by(email: new_user_email)).to be_nil
        end

        it 'set intervention invitation size correctly' do
          expect(intervention.reload.intervention_accesses.size).to eq(2)
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
