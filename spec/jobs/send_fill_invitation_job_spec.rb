# frozen_string_literal: true

RSpec.describe SendFillInvitationJob, type: :job do
  subject { described_class.perform_now(model_class, obj_id, emails, non_existing_emails, health_clinic_id) }

  let!(:user) { create(:user, :confirmed, :admin) }
  let!(:user2) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention, :published, user: user) }
  let!(:non_existing_emails) { [] }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(User).to receive(:raw_invitation_token).and_return('token')
  end

  context 'Intervention' do
    let(:model_class) { Intervention }
    let!(:obj_id) { intervention.id }
    let!(:emails) { [user2.email] }
    let!(:health_clinic_id) { nil }

    it 'sends emails only for users with notifications enabled' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq [user2.email]
    end

    context 'with health clinic' do
      let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
      let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
      let!(:health_clinic) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
      let!(:health_clinic_id) { health_clinic.id }

      it 'return proper body' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.html_part.body).to include(I18n.t('intervention_mailer.inform_to_an_email.invitation_link_from_clinic',
                                                                                    domain: ENV['WEB_URL'],
                                                                                    intervention_id: intervention.id,
                                                                                    health_clinic_id: health_clinic.id))
      end
    end

    context 'when inviting non-existing users' do
      let!(:non_existing_emails) { ['mike.wazowski@gmail.com'] }
      let!(:emails) { [] }
      let!(:totally_nonexistent_user) { create(:user, :participant, :confirmed, email: non_existing_emails.first) }
      let!(:invitation_link) do
        I18n.t('intervention_mailer.invite_to_intervention_and_registration.invitation_link',
               domain: ENV['WEB_URL'],
               intervention_id: intervention.id,
               user_role: 'participant',
               email: non_existing_emails.first,
               invitation_token: 'token').tr('&', ' ')
      end

      it do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.body.decoded.gsub('&amp;', ' ')).to include(invitation_link)
      end
    end
  end

  context 'Session' do
    let(:model_class) { Session }

    let(:intervention) { create(:intervention, user: user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:obj_id) { session.id }
    let(:emails) { [user2.email] }
    let(:health_clinic_id) { nil }

    context 'send invitation email from health clinic' do
      let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
      let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
      let!(:health_clinic) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
      let(:health_clinic_id) { health_clinic.id }
      let!(:intervention_status) { :published }
      let(:intervention) { create(:intervention, status: intervention_status) }
      let(:session) { create(:session, intervention_id: intervention.id) }

      it 'return proper body' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.html_part.body).to include(I18n.t('session_mailer.inform_to_an_email.invitation_link_from_clinic',
                                                                                    domain: ENV['WEB_URL'],
                                                                                    intervention_id: intervention.id,
                                                                                    session_id: session.id,
                                                                                    health_clinic_id: health_clinic.id))
      end
    end

    context 'when inviting non-existing users' do
      let!(:non_existing_emails) { ['mike.wazowski@gmail.com'] }
      let!(:emails) { [] }
      let!(:totally_nonexistent_user) { create(:user, :participant, :confirmed, email: non_existing_emails.first) }
      let!(:invitation_link) do
        I18n.t('session_mailer.invite_to_session_and_registration.invitation_link',
               domain: ENV['WEB_URL'],
               intervention_id: intervention.id,
               session_id: session.id,
               user_role: 'participant',
               email: non_existing_emails.first,
               invitation_token: 'token').tr('&', ' ')
      end

      it do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.body.decoded.gsub('&amp;', ' ')).to include(invitation_link)
      end
    end
  end
end
