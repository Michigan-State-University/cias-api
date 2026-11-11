# frozen_string_literal: true

require 'rails_helper'

describe Hl7::PatientDataMapper do
  subject { described_class.call(patient.id, user_session.id, 'ORU', 'R01') }

  include_context 'with HL7 settings configured'

  let!(:session) { create(:session) }
  let!(:patient) { create(:user, :with_hfhs_patient_detail, :confirmed) }
  let!(:user_session) { create(:user_session, user: patient) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question1) { create(:question_henry_ford, question_group: question_group) }
  let!(:question2) { create(:question_henry_ford, question_group: question_group) }
  let!(:answer1) { create(:answer_henry_ford, user_session: user_session, question: question1) }
  let!(:answer2) { create(:answer_henry_ford, user_session: user_session, question: question2) }

  context 'return correct data' do
    it {
      expect(subject).to include(
        "MSH|^~\\&|HTD|HFHS||HFH|#{DateTime.now.in_time_zone(ENV.fetch('HL7_REPORT_TIMEZONE')).strftime('%Y%m%d%H%M')}||ORU^R01|2|T|2.3|||",
        "PID|||#{patient.hfhs_patient_detail.patient_id}||#{patient.last_name}^#{patient.first_name}||#{patient.hfhs_patient_detail.dob.to_datetime.strftime('%Y%m%d')}|F"
      )
    }
  end

  context 'when only the old PROCESSING is set' do
    include_context 'with environment variables', { 'HL7_PROCESSING_ID' => nil, 'PROCESSING' => 'P' }

    it 'puts it in MSH-11' do
      expect(subject.first.split('|')[10]).to eq('P')
    end
  end

  context 'when HL7_PROCESSING_ID and the old PROCESSING are both blank' do
    include_context 'with environment variables', { 'HL7_PROCESSING_ID' => '', 'PROCESSING' => '' }

    it 'raises an error naming both settings instead of sending an empty MSH-11' do
      expect { subject }.to raise_error(Ehr::Settings::MissingSettingError, 'HL7_PROCESSING_ID (or PROCESSING) is not set')
    end
  end

  %w[HL7_SENDING_FACILITY HL7_RECEIVING_FACILITY].each do |setting|
    context "when #{setting} is blank" do
      include_context 'with environment variables', { setting => '' }

      it 'raises an error naming the setting instead of building the header' do
        expect { subject }.to raise_error(Ehr::Settings::MissingSettingError, "#{setting} is not set")
      end
    end
  end
end
