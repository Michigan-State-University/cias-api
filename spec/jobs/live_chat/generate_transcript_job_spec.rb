# frozen_string_literal: true

RSpec.describe LiveChat::GenerateTranscriptJob, type: :job do
  before_all { ActiveJob::Base.queue_adapter = :test }

  describe 'Intervention' do
    let(:model_class) { Intervention }
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:object) { create(:intervention, user: user, live_chat_enabled: true) }
    let(:id) { object.id }
    let(:transcript_field) { :conversations_transcript }
    let(:name) { object.name }
    let(:user_id) { user.id }

    it 'queues a job correctly' do
      described_class.perform_later(id, model_class, transcript_field, name, user_id)
      expect(described_class).to have_been_enqueued.with(id, model_class, transcript_field, name, user.id)
    end

    it 'queues an email' do
      expect { described_class.perform_now(id, model_class, transcript_field, name, user_id) }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end
  end

  describe 'Conversation' do
    let(:model_class) { LiveChat::Conversation }
    let(:user) { create(:user, :confirmed, :navigator) }
    let(:participant) { create(:user, :confirmed, :participant) }
    let(:intervention) { create(:intervention) }
    let(:object) do
      create(:live_chat_conversation, intervention: intervention, live_chat_interlocutors: [
               LiveChat::Interlocutor.new(user: user),
               LiveChat::Interlocutor.new(user: participant)
             ])
    end
    let(:id) { object.id }
    let(:transcript_field) { :transcript }
    let(:name) { intervention.name }
    let(:user_id) { user.id }

    it 'queues a job correctly' do
      described_class.perform_later(id, model_class, transcript_field, name, user_id)
      expect(described_class).to have_been_enqueued.with(id, model_class, transcript_field, name, user.id)
    end

    it 'queues an email' do
      expect { described_class.perform_now(id, model_class, transcript_field, name, user_id) }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end
  end
end
