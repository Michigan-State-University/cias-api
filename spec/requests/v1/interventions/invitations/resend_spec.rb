# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/invitations/:id/resend', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, :published, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:invitation) do
    create(:session_invitation, invitable_id: session.id, invitable_type: 'Session')
  end
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get resend_v1_intervention_invitation_path(intervention_id: intervention.id, id: invitation.id), headers: headers
  end

  before do
    allow(message_delivery).to receive(:deliver_later)
    ActiveJob::Base.queue_adapter = :test
  end

  it 'send invitation' do
    allow(SessionMailer).to receive(:inform_to_an_email).with(session, invitation.email, nil, nil).and_return(message_delivery)
    request
  end

  it 'return correct http code' do
    request
    expect(response).to have_http_status(:ok)
  end

  context 'other researcher' do
    let(:headers) { create(:user, :confirmed, :researcher).create_new_auth_token }

    it 'return correct http code' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when intervention is draft' do
    let(:intervention) { create(:intervention, :closed, user: user) }

    it 'return correct http code' do
      request
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'when user has notification disable' do
    let(:participant) { create(:user, :participant, :confirmed, email_notification: false) }
    let!(:invitation) do
      create(:session_invitation, invitable_id: session.id, invitable_type: 'Session', email: participant.email)
    end

    it 'return correct http code' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'send invitation' do
      expect(SessionMailer).not_to receive(:inform_to_an_email).with(session, invitation.email, nil)
      request
    end
  end
end
