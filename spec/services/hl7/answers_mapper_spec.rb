# frozen_string_literal: true

require 'rails_helper'

describe Hl7::AnswersMapper do
  subject { described_class.call(user_session.id) }

  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:session) { create(:session) }
  let!(:user_session) { create(:user_session) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question1) { create(:question_henry_ford, question_group: question_group) }
  let!(:question2) { create(:question_henry_ford, question_group: question_group) }
  let!(:answer1) { create(:answer_henry_ford, user_session: user_session, question: question1) }
  let!(:answer2) { create(:answer_henry_ford, user_session: user_session, question: question2) }
  let(:date_of_answer1) { answer1.created_at.strftime('%Y%m%d%H%M') }
  let(:date_of_answer2) { answer2.created_at.strftime('%Y%m%d%H%M') }

  context 'return correct data' do
    it {
      expect(subject).to include("OBX|1|ST|test||1||||||F|||#{date_of_answer1}", "OBX|2|ST|test||1||||||F|||#{date_of_answer2}")
    }
  end
end
