# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormulaRaBranchingValidation, type: :model do
  let(:intervention) { create(:intervention) }
  let!(:ra_session) { create(:ra_session, intervention: intervention) }
  let!(:classic_session) { create(:session, intervention: intervention) }
  let!(:other_classic) { create(:session, intervention: intervention) }

  let(:branching_to_session_formula) do
    [
      {
        'patterns' => [
          {
            'target' => [
              { 'type' => 'Session::Classic', 'id' => other_classic.id }
            ]
          }
        ]
      }
    ]
  end

  let(:branching_to_ra_formula) do
    [
      {
        'patterns' => [
          {
            'target' => [
              { 'type' => 'Session::ResearchAssistant', 'id' => ra_session.id }
            ]
          }
        ]
      }
    ]
  end

  describe '#no_cross_session_branching_from_ra (tested via QuestionGroup)' do
    let(:ra_question_group) { create(:question_group, session: ra_session) }
    let(:classic_question_group) { create(:question_group, session: classic_session) }

    context 'when QuestionGroup in RA session branches to another session' do
      it 'is invalid' do
        ra_question_group.formulas = branching_to_session_formula
        expect(ra_question_group).not_to be_valid
        expect(ra_question_group.errors[:formulas]).to include('Question groups in Research Assistant sessions cannot branch to other sessions')
      end
    end

    context 'when QuestionGroup in Classic session branches to another session' do
      it 'is valid' do
        classic_question_group.formulas = branching_to_session_formula
        expect(classic_question_group).to be_valid
      end
    end
  end

  describe '#no_branching_to_ra_session (tested via QuestionGroup)' do
    let(:classic_question_group) { create(:question_group, session: classic_session) }

    context 'when QuestionGroup formula targets an RA session' do
      it 'is invalid' do
        classic_question_group.formulas = branching_to_ra_formula
        expect(classic_question_group).not_to be_valid
        expect(classic_question_group.errors[:formulas]).to include('Cannot branch to a Research Assistant session')
      end
    end

    context 'when QuestionGroup formula targets a Classic session' do
      it 'is valid' do
        classic_question_group.formulas = branching_to_session_formula
        expect(classic_question_group).to be_valid
      end
    end
  end
end
