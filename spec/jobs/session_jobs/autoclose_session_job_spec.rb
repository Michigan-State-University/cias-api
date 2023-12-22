# frozen_string_literal: true

RSpec.describe SessionJobs::AutocloseSessionJob, type: :job do
  subject { described_class.perform_now(session.id) }

  let(:session) { create(:session) }
  let!(:user_sessions) { create_list(:user_session, 3, session: session) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'run finish on each user session' do
    subject
    expect(user_sessions.map(&:finished_at).compact!).eql? 3
  end
end
