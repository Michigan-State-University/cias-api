# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Csv' do
  let(:problem) { create(:problem) }
  let(:interventions) { create_list(:intervention, 5, problem_id: problem.id) }
  let(:answers) { create_list(:intervention, 5, problem_id: problem.id) }

  context 'Retrive participants' do
    context 'order particpants list' do
    end

    xit 'order particpants list ' do
    end
  end
end
