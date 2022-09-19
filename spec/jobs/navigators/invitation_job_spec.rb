# frozen_string_literal: true

RSpec.describe Navigators::InvitationJob, type: :job do
  subject { described_class.perform_now(emails, intervention.id) }

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveJob::Base.queue_adapter = :test
  end

  context 'correctly invites users to the system as navigators' do
    let!(:admin) { create(:user, :admin, :confirmed) }
    let!(:intervention) { create(:intervention, user: admin) }
    let!(:emails) { (5...10).map { |i| "email_#{i}@navigator.com" } }

    before do
      V1::LiveChat::InviteNavigators.call(emails, intervention)
    end

    it 'sends emails to all of invited users' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by emails.length
    end
  end
end
