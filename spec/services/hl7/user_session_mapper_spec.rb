# frozen_string_literal: true

require 'rails_helper'

describe Hl7::UserSessionMapper do
  subject { described_class.call(user_session.id) }

  include_context 'with HL7 settings configured'

  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:session) { create(:session) }
  let!(:patient) { create(:user, :with_hfhs_patient_detail, :confirmed) }
  let!(:user_session) { create(:user_session, finished_at: DateTime.now, user: patient) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question1) { create(:question_henry_ford, question_group: question_group) }
  let!(:question2) { create(:question_henry_ford, question_group: question_group) }
  let!(:answer1) { create(:answer_henry_ford, user_session: user_session, question: question1) }
  let!(:answer2) { create(:answer_henry_ford, user_session: user_session, question: question2) }
  let(:finished_date) { user_session.finished_at.in_time_zone(ENV.fetch('HL7_REPORT_TIMEZONE')).strftime('%Y%m%d%H%M') }

  context 'return correct data' do
    it {
      expect(subject).to include(
        'PV1||O|||||||||||||||||',
        "OBR|||||||#{finished_date}||||||||||||||||||F"
      )
    }
  end

  # The patient factory's zone (Europe/Warsaw) is never Eastern, so these pin which zone was used.
  context 'when HL7_REPORT_TIMEZONE is set' do
    include_context 'with environment variables', { 'HL7_REPORT_TIMEZONE' => 'Eastern Time (US & Canada)' }

    it 'uses it for the timestamps' do
      expect(subject).to include("OBR|||||||#{user_session.finished_at.in_time_zone('Eastern Time (US & Canada)').strftime('%Y%m%d%H%M')}||||||||||||||||||F")
    end
  end

  context 'when HL7_REPORT_TIMEZONE is blank' do
    include_context 'with environment variables', { 'HL7_REPORT_TIMEZONE' => '' }

    it "falls back to the participant's time zone instead of raising" do
      expect(subject).to include("OBR|||||||#{user_session.finished_at.in_time_zone(patient.time_zone).strftime('%Y%m%d%H%M')}||||||||||||||||||F")
    end
  end
end
