# frozen_string_literal: true

RSpec.describe CloneJobs::Intervention, type: :job do
  subject { described_class.perform_now(user, intervention.id, clone_params) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:clone_params) { {} }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Intervention).to receive(:clone)
  end

  after do
    subject
  end

  context 'email notifications enabled' do
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
