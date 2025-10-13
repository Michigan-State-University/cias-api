# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSessionJobs::SendGoodbyeMessageJob, type: :job do
  describe '#perform' do
    subject(:perform_job) { described_class.perform_now(user_session.id) }

    let(:user) { create(:user, :confirmed, :participant, :with_phone, sms_notification: true) }
    let(:intervention) { create(:intervention) }
    let(:session) { create(:session, intervention: intervention, completion_message: completion_message) }
    let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }
    let(:user_session) { create(:user_session, user: user, session: session, user_intervention: user_intervention) }
    let(:completion_message) { 'Thank you for completing the session!' }

    context 'when user session does not exist' do
      subject(:perform_job) { described_class.perform_now('non-existent-id') }

      it 'returns early without creating any messages' do
        expect { perform_job }.not_to change(Message, :count)
      end
    end

    context 'when user session exists' do
      context 'when completion message is blank' do
        let(:completion_message) { '' }

        it 'returns early without creating any messages' do
          expect { perform_job }.not_to change(Message, :count)
        end
      end

      context 'when completion message is nil' do
        let(:completion_message) { nil }

        it 'returns early without creating any messages' do
          expect { perform_job }.not_to change(Message, :count)
        end
      end

      context 'when user has sms_notification disabled' do
        let(:user) { create(:user, :confirmed, :participant, :with_phone, sms_notification: false) }

        it 'returns early without creating any messages' do
          expect { perform_job }.not_to change(Message, :count)
        end
      end

      context 'when all conditions are met for sending SMS (happy path)' do
        it 'creates a new message with correct attributes' do
          expect { perform_job }.to change(Message, :count).by(1)
        end

        it 'includes the exact completion message content' do
          perform_job

          message = Message.last
          expect(message.body).to eq('Thank you for completing the session!')
        end
      end

      context 'when user has unconfirmed phone' do
        let(:user) { create(:user, :confirmed, :participant, sms_notification: true) }

        before do
          create(:phone, user: user, confirmed: false)
        end

        it 'still attempts to send SMS (no phone confirmation check in job)' do
          expect { perform_job }.to change(Message, :count).by(1)
        end
      end

      context 'with different completion message content' do
        let(:completion_message) { 'Congratulations! You have successfully finished the intervention.' }

        it 'uses the custom completion message' do
          perform_job

          message = Message.last
          expect(message.body).to eq('Congratulations! You have successfully finished the intervention.')
        end
      end
    end

    context 'with SMS user session type' do
      let(:user_session) { create(:sms_user_session, user: user, session: session, user_intervention: user_intervention) }

      it 'works the same way for SMS user sessions' do
        expect { perform_job }.to change(Message, :count).by(1)

        message = Message.last
        expect(message.phone).to eq(user.phone.full_number)
        expect(message.body).to eq(completion_message)
      end
    end

    context 'with different phone number formats' do
      let(:user) do
        user = create(:user, :confirmed, :participant, sms_notification: true)
        create(:phone, user: user, prefix: '+1', iso: 'US', number: '5551234567', confirmed: true)
        user
      end

      it 'handles different phone formats correctly' do
        perform_job

        message = Message.last
        expect(message.phone).to eq('+15551234567')
      end
    end
  end
end
