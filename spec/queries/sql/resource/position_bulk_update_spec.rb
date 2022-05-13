# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PositionBulkUpdate', type: :model do
  let(:intervention) { create(:intervention) }
  let(:sessions) { create_list(:session, 3, intervention_id: intervention.id) }

  let(:session) { create(:session) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question1) { create(:question_slider, question_group_id: question_group.id, position: 1) }
  let(:question2) { create(:question_bar_graph, question_group_id: question_group.id, position: 2) }
  let(:question3) { create(:question_information, question_group_id: question_group.id, position: 3) }
  let(:question_position_params) do
    {
      position: [
        {
          id: question1.id,
          position: 33
        },
        {
          id: question2.id,
          position: 11
        },
        {
          id: question3.id,
          position: 22
        }
      ]
    }
  end
  let(:session_position_params) do
    {
      position: [
        {
          id: sessions[0].id,
          position: 55
        },
        {
          id: sessions[1].id,
          position: 33
        },
        {
          id: sessions[2].id,
          position: 88
        }
      ]
    }
  end

  describe 'Questions update position' do
    before do
      SqlQuery.new(
        'resource/position_bulk_update',
        values: question_position_params[:position],
        table: 'questions'
      ).execute

      question1.reload
      question2.reload
      question3.reload
    end

    it { expect(question1.position).to eq(33) }
    it { expect(question2.position).to eq(11) }
    it { expect(question3.position).to eq(22) }
  end

  describe 'Session update position' do
    before do
      SqlQuery.new(
        'resource/position_bulk_update',
        values: session_position_params[:position],
        table: 'sessions'
      ).execute

      sessions[0].reload
      sessions[1].reload
      sessions[2].reload
    end

    it { expect(sessions[0].position).to eq(55) }
    it { expect(sessions[1].position).to eq(33) }
    it { expect(sessions[2].position).to eq(88) }
  end
end
