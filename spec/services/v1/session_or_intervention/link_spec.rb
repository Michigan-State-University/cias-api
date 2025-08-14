# frozen_string_literal: true

RSpec.describe V1::SessionOrIntervention::Link do
  include ActiveJob::TestHelper

  subject { described_class.call(session, health_clinic, email) }

  let!(:user) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:intervention) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:health_clinic) { nil }
  let(:email) { user.email }

  it 'returns link to the session' do
    expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone',
                                 domain: ENV.fetch('WEB_URL', nil),
                                 session_id: session.id,
                                 intervention_id: intervention.id,
                                 language_code: intervention.language_code,
                                 warning_screen_enabled: intervention.warning_screen_enabled))
  end

  context 'link as information about health clinic' do
    let!(:health_clinic) { create(:health_clinic) }

    it 'returns link to the session in organization' do
      expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone_from_clinic',
                                   domain: ENV.fetch('WEB_URL', nil),
                                   session_id: session.id,
                                   intervention_id: intervention.id,
                                   health_clinic_id: health_clinic.id,
                                   language_code: intervention.language_code,
                                   warning_screen_enabled: intervention.warning_screen_enabled))
    end
  end

  context 'intervention with restrictions' do
    let!(:intervention) { create(:intervention, shared_to: 'registered') }

    it 'returns link to the session or registration' do
      expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link',
                                   domain: ENV.fetch('WEB_URL', nil),
                                   intervention_id: intervention.id,
                                   session_id: session.id,
                                   language_code: intervention.language_code,
                                   warning_screen_enabled: intervention.warning_screen_enabled))
    end
  end

  context 'for predefined participant' do
    let!(:user) { create(:user, :confirmed, :predefined_participant) }

    it 'returns short link' do
      expect(subject).to eq("#{ENV.fetch('WEB_URL', nil)}/usr/#{user.predefined_user_parameter.slug}")
    end
  end

  context 'when user does not exist' do
    let(:email) { 'some@example.com' }

    it 'returns link to the session' do
      expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone',
                                   domain: ENV.fetch('WEB_URL', nil),
                                   session_id: session.id,
                                   intervention_id: intervention.id,
                                   language_code: intervention.language_code,
                                   warning_screen_enabled: intervention.warning_screen_enabled))
    end
  end
end
