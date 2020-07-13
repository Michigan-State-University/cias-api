# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Question::PositionBulkUpdate', type: :model do
  let(:intervention) { create(:intervention_single) }
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

  describe 'update position' do
    before do
      SqlQuery.new(
        'question/position_bulk_update',
        values: question_position_params[:position]
      ).execute

      question_1.reload
      question_2.reload
      question_3.reload
    end

    it { expect(question_1.position).to eq(33) }
    it { expect(question_2.position).to eq(11) }
    it { expect(question_3.position).to eq(22) }
  end
end
