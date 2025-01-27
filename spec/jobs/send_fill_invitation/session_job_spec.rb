# frozen_string_literal: true

RSpec.describe SendFillInvitation::SessionJob, type: :job do
  subject { described_class.perform_now(session.id, emails, non_existing_emails, health_clinic_id, intervention_id) }

  let!(:user) { create(:user, :confirmed, :admin) }
  let!(:user2) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention, :published, user: user) }
  let!(:non_existing_emails) { [] }
  let!(:session) { create(:session, intervention: intervention) }
  let(:emails) { [user2.email] }
  let(:health_clinic_id) { nil }
  let(:intervention_id) { intervention.id }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(User).to receive(:raw_invitation_token).and_return('token')
  end

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
      expect(
        ActionMailer::Base.deliveries.last.html_part.body.decoded.gsub('&amp;', ' ')
      ).to include(I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone_from_clinic',
                          domain: ENV.fetch('WEB_URL', nil),
                          intervention_id: intervention.id,
                          session_id: session.id,
                          health_clinic_id: health_clinic.id,
                          language_code: intervention.language_code).tr('&', ' '))
    end

    context 'shared to registered sends correct email' do
      let(:intervention) { create(:intervention, status: intervention_status, shared_to: :registered) }
      let(:health_clinic_id) { nil }

      it do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.html_part.body).to include(I18n.t('session_mailer.inform_to_an_email.invitation_link',
                                                                                    domain: ENV.fetch('WEB_URL', nil),
                                                                                    intervention_id: intervention.id,
                                                                                    session_id: session.id,
                                                                                    health_clinic_id: health_clinic.id,
                                                                                    language_code: intervention.language_code))
      end
    end
  end

  context 'send invitation to predefined participant' do
    let!(:intervention) { create(:intervention, :published, :with_predefined_participants, user: user) }
    let(:predefined_participant) { intervention.predefined_users.first }
    let(:emails) { [predefined_participant.email] }

    it do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.html_part.body).to include("#{ENV.fetch('WEB_URL',
                                                                                        nil)}/usr/#{predefined_participant.predefined_user_parameter.slug}")
    end
  end

  context 'when inviting non-existing users' do
    let!(:non_existing_emails) { ['mike.wazowski@gmail.com'] }
    let!(:emails) { [] }
    let!(:invitation_link) do
      I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone',
             domain: ENV.fetch('WEB_URL', nil),
             session_id: session.id,
             intervention_id: session.intervention_id,
             language_code: session.language_code)
    end

    it do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.html_part.body.decoded.gsub('&amp;', ' ')).to include(invitation_link)
    end
  end

  context 'with scheduled session' do
    let(:scheduled_at) { DateTime.now + 2.days }
    let!(:user_intervention) { create(:user_intervention, intervention: session.intervention, user: user2) }
    let!(:user_session) { create(:user_session, user: user2, session: session, scheduled_at: scheduled_at, user_intervention: user_intervention) }

    it do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(ActionMailer::Base.deliveries.last.html_part.body).to include(I18n.t('session_mailer.inform_to_an_email.session_scheduled',
                                                                                  date: user_session.scheduled_at))
    end

    context 'scheduled at from past' do
      let(:scheduled_at) { DateTime.now - 2.days }

      it do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(ActionMailer::Base.deliveries.last.html_part.body).not_to include(I18n.t('session_mailer.inform_to_an_email.session_scheduled',
                                                                                        date: user_session.scheduled_at))
      end
    end
  end
end
