# frozen_string_literal: true

require 'rails_helper'
require 'support/predefined_participant_sms_helpers'

RSpec.describe 'scheduled reminder from the invitation request to delivery', type: :request do
  include ActiveJob::TestHelper
  include PredefinedParticipantSmsHelpers

  let(:researcher) { create(:user, :researcher, :confirmed, time_zone: 'America/New_York') }
  let!(:intervention) { create(:intervention, :published, user: researcher) }
  let!(:opener) { make_participant(intervention, index: 0) }
  let!(:silent) { make_participant(intervention, index: 1) }
  let(:payload) do
    { sms_campaign: { kind: 'invitation', body: 'CIAS_TDD_INVITATION', links: [],
                      scheduled_reminder: { body: 'CIAS_TDD_REMINDER', days_after: 3, links: [] } } }
  end

  around { |example| travel_to(PredefinedParticipantSmsHelpers::NOW) { example.run } }

  before do
    stub_const('ENV', ENV.to_hash.merge('WEB_URL' => 'https://web.example.test'))
    allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
  end

  def phones_messaged_with(text)
    Message.where('body LIKE ?', "#{text}%").map(&:phone)
  end

  def reminder
    PredefinedParticipants::SmsCampaign.find_by!(kind: 'scheduled_reminder')
  end

  it 'invites everyone now and X days later reminds only the participant who has not opened the link, at the same local time' do
    post "/v1/interventions/#{intervention.id}/predefined_participants/sms_campaigns",
         params: payload, headers: researcher.create_new_auth_token, as: :json
    expect(response).to have_http_status(:accepted)

    perform_enqueued_jobs(at: Time.current)
    expect(phones_messaged_with('CIAS_TDD_INVITATION')).to contain_exactly(opener.user.phone.full_number, silent.user.phone.full_number)
    expect(phones_messaged_with('CIAS_TDD_REMINDER')).to be_empty
    expect(reminder.status).to eq('scheduled')

    post v1_verify_predefined_participant_path, params: { slug: opener.slug }
    expect(opener.reload.first_opened_at).to be_present

    due = reminder.scheduled_at
    expect(due.in_time_zone('America/New_York').strftime('%F %H:%M')).to eq('2026-11-02 08:00')

    travel_to(due - 1.minute)
    perform_enqueued_jobs(at: Time.current)
    expect(phones_messaged_with('CIAS_TDD_REMINDER')).to be_empty

    travel_to(due)
    perform_enqueued_jobs(at: Time.current)
    expect(phones_messaged_with('CIAS_TDD_REMINDER')).to eq([silent.user.phone.full_number])
    expect(reminder).to have_attributes(status: 'sent', accepted_count: 1, recipients_count: 1)
    expect([silent.reload.last_reminder_sent_at, opener.reload.last_reminder_sent_at]).to eq([due, nil])
  end
end
