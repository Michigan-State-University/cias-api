# frozen_string_literal: true

RSpec.describe V1::SessionOrIntervention::Link do
  include ActiveJob::TestHelper

  subject { described_class.call(session_or_intervention, health_clinic, email) }

  let!(:user) { create(:user, :confirmed, :participant) }
  let!(:session_or_intervention) { create(:session) }
  let!(:health_clinic) { nil }
  let(:email) { user.email }

  it 'returns link to the session' do
    expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone',
                                 domain: ENV['WEB_URL'], session_id: session_or_intervention.id,
                                 intervention_id: session_or_intervention.intervention_id))
  end

  context 'link as information about health clinic' do
    let!(:health_clinic) { create(:health_clinic) }

    it 'returns link to the session in organization' do
      expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone_from_clinic',
                                   domain: ENV['WEB_URL'], session_id: session_or_intervention.id,
                                   intervention_id: session_or_intervention.intervention_id,
                                   health_clinic_id: health_clinic.id))
    end
  end

  context 'intervention with restrictions' do
    let!(:session_or_intervention) { create(:session, intervention: create(:intervention, shared_to: 'registered')) }

    it 'returns link to the session or registration' do
      expect(subject).to eq(I18n.t('session_mailer.inform_to_an_email.invitation_link',
                                   domain: ENV['WEB_URL'],
                                   intervention_id: session_or_intervention.intervention_id, session_id: session_or_intervention.id))
    end
  end

  context 'for predefined participant' do
    let!(:user) { create(:user, :confirmed, :predefined_participant) }

    it 'returns short link' do
      expect(subject).to eq("#{ENV['WEB_URL']}/usr/#{user.predefined_user_parameter.slug}")
    end
  end

  context 'when user does not exist' do
    let(:email) { 'some@example.com' }

    it {
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    }
  end
end
