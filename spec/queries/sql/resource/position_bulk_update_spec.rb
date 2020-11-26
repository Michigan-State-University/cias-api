# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PositionBulkUpdate', type: :model do
  let(:problem) { create(:problem) }
  let(:sessions) { create_list(:session, 3, problem_id: problem.id) }

  let(:session) { create(:session) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question_1) { create(:question_slider, question_group_id: question_group.id, position: 1) }
  let(:question_2) { create(:question_bar_graph, question_group_id: question_group.id, position: 2) }
  let(:question_3) { create(:question_information, question_group_id: question_group.id, position: 3) }
  let(:question_position_params) do
    {
      position: [
        {
          id: question_1.id,
          position: 33
        },
        {
          id: question_2.id,
          position: 11
        },
        {
          id: question_3.id,
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

      question_1.reload
      question_2.reload
      question_3.reload
    end

    it { expect(question_1.position).to eq(33) }
    it { expect(question_2.position).to eq(11) }
    it { expect(question_3.position).to eq(22) }
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
