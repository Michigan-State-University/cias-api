# frozen_string_literal: true

require 'rails_helper'

describe SessionJob::Publish, type: :job do
  include ActiveJob::TestHelper

  it { should be_processed_in :default }

  context 'checks retry ability' do
    let(:attempts) { Settings.sidekiq.retries }

    before do
      allow_any_instance_of(described_class).to receive(:perform).and_raise(StandardError.new) # rubocop:disable RSpec/AnyInstance
    end

    it { should be_retryable true }

    it 'makes 2 attempts' do
      assert_performed_jobs attempts do
        described_class.perform_later
      rescue StandardError
        nil
      end
    end
  end

  describe '#perform' do
    let(:intervention) { create :intervention, :published }
    let(:session) { create :session, intervention: intervention }

    it 'belongs to correct class' do
      expect(subject).to be_an_instance_of(described_class)
    end

    context 'if session has no user' do
      it 'will not call mailer' do
        expect(subject).not_to receive(:inform_participants) # rubocop:disable RSpec/SubjectStub
      end
    end

    context 'if session has participant' do
      let(:invitation) { create(:session_invitation, session: session) }

      it 'will call mailer with correct params' do
        expect(subject).to receive(:inform_participants).with([invitation.email], session) # rubocop:disable RSpec/SubjectStub

        subject.perform(session.id)
      end
    end
  end
end
