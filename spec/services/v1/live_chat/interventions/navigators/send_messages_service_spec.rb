# frozen_string_literal: true

RSpec.describe V1::LiveChat::Interventions::Navigators::SendMessages do
  let(:subject) { described_class.call(intervention, message_type) }

  let!(:user) { create(:user, :admin, :confirmed) }
  let!(:navigator) { create(:user, :navigator, :confirmed) }
  let!(:navigator2) { create(:user, :navigator, :confirmed) }
  let!(:intervention) { create(:intervention, user: user, navigators: [navigator, navigator2]) }
  let!(:owner_phone) { create(:phone, :confirmed, user: user) }
  let!(:navigator_phone) { create(:phone, :confirmed, user: navigator) }
  let!(:message_type) { 'call_out' }

  context 'call_out' do
    context 'correctly sends emails' do
      let!(:mails) { ActionMailer::Base.deliveries }

      it 'to all navigators and intervention owner' do
        expect { subject }.to change(mails, :size).by(3)
      end

      it 'with correct subject' do
        subject
        expect(mails.last.subject).to eq 'Participant requested for assist!'
      end

      context 'when intervention owner has also navigator role' do
        let!(:user) { create(:user, :researcher_and_navigator, :confirmed) }

        it 'dont send extra email' do
          expect { subject }.to change(mails, :size).by(3)
        end
      end
    end

    context 'correctly sends SMS messages' do
      it 'only to users which given their phone numbers' do
        expect { subject }.to change(Message, :count).by(2)
      end

      context 'when intervention owner has also navigator role' do
        let!(:user) { create(:user, :researcher_and_navigator, :confirmed) }

        it 'dont send extra sms message' do
          expect { subject }.to change(Message, :count).by(2)
        end
      end
    end
  end

  context 'cancel_call_out' do
    let(:message_type) { 'cancel_call_out' }
    let(:subject) { described_class.call(intervention, message_type, navigator) }

    context 'correctly sends emails' do
      let!(:mails) { ActionMailer::Base.deliveries }

      it 'to all navigators and intervention owner without excluded user' do
        expect { subject }.to change(mails, :size).by(2)
      end

      it 'with correct subject' do
        subject
        expect(mails.last.subject).to eq 'Participant request for assist - canceled'
      end

      context 'when intervention owner has also navigator role' do
        let!(:user) { create(:user, :researcher_and_navigator, :confirmed) }

        it 'dont send extra email' do
          expect { subject }.to change(mails, :size).by(2)
        end
      end
    end

    context 'correctly sends SMS messages' do
      it 'only to users which given their phone numbers without excluded user' do
        expect { subject }.to change(Message, :count).by(1)
      end

      context 'when intervention owner has also navigator role' do
        let!(:user) { create(:user, :researcher_and_navigator, :confirmed) }

        it 'dont send extra sms message' do
          expect { subject }.to change(Message, :count).by(1)
        end
      end
    end
  end
end
