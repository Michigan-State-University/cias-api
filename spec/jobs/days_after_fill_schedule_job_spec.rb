# frozen_string_literal: true

RSpec.describe DaysAfterFillScheduleJob, type: :job do
  let!(:session) { create(:session) }
  let!(:user) { create(:user, :participant) }
  let(:session_id) { session.id }
  let(:user_id) { user.id }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Session).to receive(:find_by).with(id: session.id).and_return(session)
    allow(Session).to receive(:find_by).with(id: 'invalid_session_id').and_return(nil)
    allow(User).to receive(:find_by).with(id: user.id).and_return(user)
    allow(User).to receive(:find_by).with(id: 'invalid_user_id').and_return(nil)
  end

  after do
    described_class.new.perform(session_id, user_id)
  end

  context 'user session timeout body' do
    context 'with correct session and user id' do
      it 'calls finish on perform' do
        expect(session).to receive(:send_link_to_session)
      end
    end

    context 'with incorrect session id' do
      let(:session_id) { 'invalid_session_id' }

      it 'does not call finish on perform' do
        expect_any_instance_of(Session).not_to receive(:send_link_to_session)
      end
    end

    context 'with incorrect user id' do
      let(:user_id) { 'invalid_user_id' }

      it 'does not call finish on perform' do
        expect_any_instance_of(Session).not_to receive(:send_link_to_session)
      end
    end
  end
end
