# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PredefinedParticipantSerializer do
  let(:opened_at) { Time.zone.local(2026, 11, 2, 9, 30, 0) }
  let(:reminder_at) { Time.zone.local(2026, 11, 5, 10, 0, 0) }
  let(:participant) { create(:user, :predefined_participant, :with_phone) }
  let(:parameter) { participant.predefined_user_parameter }
  let(:attributes) { described_class.new(participant.reload).serializable_hash[:data][:attributes] }

  it 'exposes first_opened_at and last_reminder_sent_at' do
    expect(attributes.keys).to include(:first_opened_at, :last_reminder_sent_at)
  end

  it 'returns nil for both fields on a participant that was never opened or reminded' do
    expect(attributes).to include(first_opened_at: nil, last_reminder_sent_at: nil)
  end

  it 'returns the stored values from predefined_user_parameter' do
    parameter.update_columns(first_opened_at: opened_at, last_reminder_sent_at: reminder_at)

    expect(attributes[:first_opened_at]).to be_within(1.second).of(opened_at)
    expect(attributes[:last_reminder_sent_at]).to be_within(1.second).of(reminder_at)
  end

  it 'keeps the two fields independent of each other' do
    parameter.update_column(:first_opened_at, opened_at)

    expect(attributes[:first_opened_at]).to be_within(1.second).of(opened_at)
    expect(attributes[:last_reminder_sent_at]).to be_nil
  end

  it 'keeps the attributes that were already delegated to predefined_user_parameter' do
    parameter.update_columns(external_id: 'tdd-ext-1', sms_notification: true)

    expect(attributes).to include(slug: parameter.slug, external_id: 'tdd-ext-1', sms_notification: true)
  end

  it 'keeps every previously delegated attribute' do
    expect(attributes.keys).to include(:slug, :auto_invitation, :sms_invitation_sent_at, :email_invitation_sent_at, :health_clinic_id,
                                       :external_id, :sms_notification, :email_notification)
  end
end
