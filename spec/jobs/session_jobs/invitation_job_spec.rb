# frozen_string_literal: true

RSpec.describe SessionJobs::Invitation, type: :job do
  subject { described_class.perform_now(session.id, emails) }

  let(:user_with_notification) { create(:user, :confirmed) }
  let(:user_without_notification) { create(:user, :confirmed, email_notification: false) }
  let(:emails) { [user_with_notification.email, user_without_notification.email] }

  let(:session) { create(:session) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'send emails only for users with enabled email notifications' do
    expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq [user_with_notification.email]
  end
end
