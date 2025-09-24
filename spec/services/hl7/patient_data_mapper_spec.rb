# frozen_string_literal: true

require 'rails_helper'

describe Hl7::PatientDataMapper do
  subject { described_class.call(patient.id, user_session.id, 'ORU', 'R01') }

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
        "MSH|^~\\&|HTD|HFHS||HFH|#{DateTime.now.in_time_zone(ENV.fetch('HFH_REPORT_TIMEZONE', nil)).strftime('%Y%m%d%H%M')}||ORU^R01|2|#{ENV.fetch('PROCESSING')}|2.3|||",
        "PID|||#{patient.hfhs_patient_detail.patient_id}||#{patient.last_name}^#{patient.first_name}||#{patient.hfhs_patient_detail.dob.to_datetime.strftime('%Y%m%d')}|F"
      )
    }
  end
end
