# frozen_string_literal: true

RSpec.describe Interventions::InvitationJob, type: :job do
  subject { described_class.perform_now(intervention.id, emails) }

  let(:user_with_notification) { create(:user, :confirmed) }
  let(:user_without_notification) { create(:user, :confirmed, email_notification: false) }
  let(:emails) { [user_with_notification.email, user_without_notification.email] }

  let(:intervention) { create(:intervention, :published) }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'send emails only for users with enabled email notifications' do
    expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq [user_with_notification.email]
  end

  context 'send invitation email from health clinic' do
    subject { described_class.perform_now(intervention.id, emails, health_clinic.id) }

    let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
    let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
    let!(:health_clinic) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }

    it 'return proper body' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.html_part.body).to include(I18n.t('intervention_mailer.inform_to_an_email.invitation_link_from_clinic',
                                                                                  domain: ENV['WEB_URL'],
                                                                                  intervention_id: intervention.id,
                                                                                  health_clinic_id: health_clinic.id))
    end
  end
end
