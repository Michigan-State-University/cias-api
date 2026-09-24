# frozen_string_literal: true

RSpec.describe UserSessionTimeoutJob, type: :job do
  before { ActiveJob::Base.queue_adapter = :test }

  context 'user session timeout body' do
    let!(:user_session) { create(:user_session) }
    let(:user_session_id) { user_session.id }

    before do
      allow(UserSession).to receive(:find_by).with(id: user_session.id).and_return(user_session)
      allow(UserSession).to receive(:find_by).with(id: 'invalid_user_id').and_return(nil)
    end

    after do
      described_class.new.perform(user_session_id)
    end

    context 'with correct user_session_id' do
      it 'calls finish on perform' do
        expect(user_session).to receive(:finish)
      end
    end

    context 'with incorrect user_session_id' do
      let(:user_session_id) { 'invalid_user_id' }

      it 'does not call finish on perform' do
        expect_any_instance_of(UserSession).not_to receive(:finish)
      end
    end
  end

  describe 'inactivity timeout' do
    let(:session) { create(:session, autofinish_enabled: false) }
    let(:user_session) { create(:user_session, session: session) }

    # Pinned so the expectations below do not follow whatever INACTIVITY_TIMEOUT_DELAY_MINUTES
    # the local environment happens to set.
    before { stub_const('UserSession::ClassicBehavior::INACTIVITY_TIMEOUT_DELAY', 30.minutes) }

    context 'when the last answer still falls inside the inactivity window' do
      before { user_session.update!(last_answer_at: 5.minutes.ago) }

      it 'does not finish the session' do
        expect { described_class.new.perform(user_session.id, 'inactivity_timeout') }
          .not_to change { user_session.reload.finished_at }.from(nil)
      end

      it 'rearms the timeout for the remaining part of the window' do
        expect { described_class.new.perform(user_session.id, 'inactivity_timeout') }
          .to have_enqueued_job(described_class)
          .with(user_session.id, 'inactivity_timeout')
          .at(a_value_within(1.minute).of(25.minutes.from_now))
      end
    end

    context 'when the last answer is older than the window' do
      before { user_session.update!(last_answer_at: 31.minutes.ago) }

      it 'finishes the session and records why' do
        expect { described_class.new.perform(user_session.id, 'inactivity_timeout') }
          .to change { user_session.reload.finish_reason }.from(nil).to('inactivity_timeout')
      end
    end
  end
end
