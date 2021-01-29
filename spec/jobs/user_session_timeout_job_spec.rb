# frozen_string_literal: true

RSpec.describe UserSessionTimeoutJob, type: :job do
  let!(:user_session) { create(:user_session) }
  let(:user_session_id) { user_session.id }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(UserSession).to receive(:find_by).with(id: user_session.id).and_return(user_session)
    allow(UserSession).to receive(:find_by).with(id: 'invalid_user_id').and_return(nil)
  end

  after do
    described_class.new.perform(user_session_id)
  end

  context 'user session timeout body' do
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
end
