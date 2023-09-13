# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invitation, type: :model do
  subject { create(:invitation, email: invited.email, invitable: session) }

  let!(:session) { create(:session) }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  describe '#resend' do
    before do
      allow(message_delivery).to receive(:deliver_later)
      ActiveJob::Base.queue_adapter = :test
    end

    context 'email notification enabled' do
      let(:invited) { create(:user, :confirmed, email: 'invited@test.org') }

      it 'send email' do
        expect(SessionMailer).to receive(:inform_to_an_email).with(session, invited.email, nil, nil).and_return(message_delivery)
        subject.resend
      end
    end

    context 'email notification disabled' do
      let(:invited) { create(:user, :confirmed, email_notification: false) }

      it "Don't send email" do
        expect(SessionMailer).not_to receive(:inform_to_an_email)
        subject.resend
      end
    end

    context 'when user session exists' do
      let(:invited) { create(:user, :confirmed) }
      let!(:user_session) { create(:user_session, user: invited, session: session, scheduled_at: DateTime.now + 2.days) }
      let(:scheduled_at) { user_session.scheduled_at }

      it 'send email' do
        expect(SessionMailer).to receive(:inform_to_an_email).with(session, invited.email, nil, scheduled_at).and_return(message_delivery)
        subject.resend
      end
    end
  end
end
