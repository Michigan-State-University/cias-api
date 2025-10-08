# frozen_string_literal: true

RSpec.describe UserSessionJobs::SendGoodbyeMessageJob, type: :job do
  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(
      {
        status: 200
      }
    )
  end

  describe '#perform' do
    let(:user) { create(:user, :with_phone) }
    let(:intervention) { create(:intervention) }
    let(:session) { create(:sms_session, intervention: intervention, completion_message: completion_message) }
    let(:user_session) { create(:sms_user_session, user: user, session: session) }
    let(:completion_message) { 'Thank you for completing the session!' }

    subject { described_class.perform_now(user_session.id) }

    context 'when user session exists' do
      context 'when session has completion message' do
        it 'creates a Message record' do
          expect { subject }.to change(Message, :count).by(1)
        end

        it 'creates message with correct phone number' do
          subject
          message = Message.last
          expect(message.phone).to eq(user.full_number)
        end

        it 'creates message with completion message content' do
          subject
          message = Message.last
          expect(message.body).to eq(completion_message)
        end

        it 'creates message with no attachment' do
          subject
          message = Message.last
          expect(message.attachment_url).to be_nil
        end

        it 'calls Communication::Sms to send the message' do
          expect_any_instance_of(Communication::Sms).to receive(:send_message)
          subject
        end
      end

      context 'when session has no completion message' do
        let(:completion_message) { nil }

        it 'does not create a Message record' do
          expect { subject }.not_to change(Message, :count)
        end

        it 'does not call Communication::Sms' do
          expect_any_instance_of(Communication::Sms).not_to receive(:send_message)
          subject
        end
      end

      context 'when session has empty completion message' do
        let(:completion_message) { '' }

        it 'does not create a Message record' do
          expect { subject }.not_to change(Message, :count)
        end

        it 'does not call Communication::Sms' do
          expect_any_instance_of(Communication::Sms).not_to receive(:send_message)
          subject
        end
      end
    end

    context 'when user session does not exist' do
      subject { described_class.perform_now(999999) }

      it 'does not create a Message record' do
        expect { subject }.not_to change(Message, :count)
      end

      it 'does not call Communication::Sms' do
        expect_any_instance_of(Communication::Sms).not_to receive(:send_message)
        subject
      end

      it 'does not raise an error' do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe 'queue configuration' do
    it 'is queued in the question_sms queue' do
      expect(described_class.queue_name).to eq('question_sms')
    end
  end

  describe 'job enqueueing' do
    let(:user_session) { create(:sms_user_session) }

    it 'can be enqueued' do
      expect do
        described_class.perform_later(user_session.id)
      end.to have_enqueued_job(described_class).with(user_session.id)
    end
  end
end