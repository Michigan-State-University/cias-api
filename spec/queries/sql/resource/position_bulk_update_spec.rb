# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PositionBulkUpdate', type: :model do
  let(:problem) { create(:problem) }
  let(:interventions) { create_list(:intervention, 3, problem_id: problem.id) }

  let(:intervention) { create(:intervention) }
  let(:question_1) { create(:question_analogue_scale, intervention_id: intervention.id, position: 1) }
  let(:question_2) { create(:question_bar_graph, intervention_id: intervention.id, position: 2) }
  let(:question_3) { create(:question_information, intervention_id: intervention.id, position: 3) }
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
  let(:intervention_position_params) do
    {
      position: [
        {
          id: interventions[0].id,
          position: 55
        },
        {
          id: interventions[1].id,
          position: 33
        },
        {
          id: interventions[2].id,
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

  describe 'Intervention update position' do
    before do
      SqlQuery.new(
        'resource/position_bulk_update',
        values: intervention_position_params[:position],
        table: 'interventions'
      ).execute

      interventions[0].reload
      interventions[1].reload
      interventions[2].reload
    end

    it { expect(interventions[0].position).to eq(55) }
    it { expect(interventions[1].position).to eq(33) }
    it { expect(interventions[2].position).to eq(88) }
  end
end
