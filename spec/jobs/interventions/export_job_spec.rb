# frozen_string_literal: true

RSpec.describe Interventions::ExportJob, type: :job do
  subject { described_class.perform_now(user_id, intervention_id) }

  let(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user) }
  let(:user_id) { user.id }
  let(:intervention_id) { intervention.id }

  context 'email notification enabled' do
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
