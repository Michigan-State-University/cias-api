# frozen_string_literal: true

require 'rails_helper'

describe Hl7::AnswersMapper do
  subject { described_class.call(user_session.id) }

  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:session) { create(:session) }
  let!(:user_session) { create(:user_session, finished_at: 2.days.ago) }
  let!(:question_group) { create(:question_group, session: session) }
  let!(:question1) { create(:question_henry_ford, question_group: question_group) }
  let!(:question2) { create(:question_henry_ford, question_group: question_group) }
  let!(:answer1) do
    create(:answer_henry_ford, user_session: user_session, question: question1, body:
    { data: [
      {
        var: 'test',
        value: '1',
        hfh_value: 'hfh_value1'
      }
    ] })
  end
  let!(:answer2) do
    create(:answer_henry_ford, user_session: user_session, question: question2, body:
    { data: [
      {
        var: 'test',
        value: '2',
        hfh_value: 'hfh_value2'
      }
    ] })
  end
  let(:date_of_answer) { user_session.finished_at.strftime('%Y%m%d%H%M') }

  context 'return correct data' do
    it {
      expect(subject).to include("OBX|1|ST|test||hfh_value1||||||F|||#{date_of_answer}", "OBX|2|ST|test||hfh_value2||||||F|||#{date_of_answer}")
    }
  end
end
