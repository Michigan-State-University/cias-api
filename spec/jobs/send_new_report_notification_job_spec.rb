# frozen_string_literal: true

RSpec.describe SendNewReportNotificationJob, type: :job do
  subject { described_class.perform_now(user.email) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  context 'email notifications enabled' do
    let!(:user) { create(:user, :confirmed, :researcher) }

    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'email notifications disabled' do
    let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

    it "Don't send email" do
      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
