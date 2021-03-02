# frozen_string_literal: true

RSpec.describe GenerateUserSessionReportsJob, type: :job do
  subject { described_class.perform_now(user_session.id) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:user_session) { create(:user_session) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'call generate pdf preview service' do
    expect(V1::GeneratedReports::GenerateUserSessionReports).to receive(:call).with(
      user_session
    )
    subject
  end
end
