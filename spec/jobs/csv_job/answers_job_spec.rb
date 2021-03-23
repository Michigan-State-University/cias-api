# frozen_string_literal: true

RSpec.describe CsvJob::Answers, type: :job do
  subject { described_class.perform_now(user.id, intervention.id, requested_at) }

  let(:requested_at) { Time.current }
  let(:intervention) { create(:intervention) }

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
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end
  end
end
