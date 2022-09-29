# frozen_string_literal: true

require 'rails_helper'

describe Hl7::UserSessionMapper do
  subject { described_class.call(user_session.id) }

  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:session) { create(:session) }
  let!(:patient) { create(:user, :with_hfhs_patient_detail, :confirmed) }
  let!(:user_session) { create(:user_session, finished_at: DateTime.now, user: patient) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question1) { create(:question_henry_ford, question_group: question_group) }
  let!(:question2) { create(:question_henry_ford, question_group: question_group) }
  let!(:answer1) { create(:answer_henry_ford, user_session: user_session, question: question1) }
  let!(:answer2) { create(:answer_henry_ford, user_session: user_session, question: question2) }
  let(:finished_date) { user_session.finished_at.strftime('%Y%m%d%H%M') }

  context 'return correct data' do
    it {
      expect(subject).to include(
        'PV1||O|||||||||||||||||',
        "OBR|||||||#{finished_date}||||||||||||||||||F"
      )
    }
  end
end
