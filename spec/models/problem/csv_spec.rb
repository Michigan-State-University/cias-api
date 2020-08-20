# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Csv' do
  let(:problem) { create(:problem) }
  let(:interventions) { create_list(:intervention, 5, problem_id: problem.id) }
  let(:answers) { create_list(:intervention, 5, problem_id: problem.id) }

  xcontext 'Retrieve participants' do
    context 'order participants list' do
      it 'order participants list ' do
      end
    end

    it 'order participants list ' do
    end
  end
end
