# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RA session question variable requirement', type: :model do
  let(:intervention) { create(:intervention) }
  let(:ra_session) { create(:ra_session, intervention: intervention) }
  let(:ra_question_group) { create(:question_group, session: ra_session) }

  # Builds a question in `group` with the variable name forced to `variable_name`,
  # robust to whichever key type the factory body uses.
  def question_with_variable(factory, variable_name, group: ra_question_group)
    build(factory, question_group: group).tap do |question|
      body = question.body.deep_stringify_keys
      body['variable'] ||= {}
      body['variable']['name'] = variable_name
      question.body = body
    end
  end

  describe 'auto-assigning a default variable on create' do
    %i[question_single question_number question_date].each do |factory|
      it "assigns a default variable to a blank #{factory}" do
        question = question_with_variable(factory, '')
        question.save!
        expect(question.reload.body.dig('variable', 'name')).to be_present
      end
    end

    it 'preserves an explicitly provided variable' do
      question = question_with_variable(:question_single, 'systolic_bp')
      question.save!
      expect(question.reload.body.dig('variable', 'name')).to eq('systolic_bp')
    end

    it 'assigns distinct defaults to multiple blank questions in the same session' do
      first = question_with_variable(:question_single, '')
      first.save!
      second = question_with_variable(:question_number, '')
      second.save!

      expect(first.reload.body.dig('variable', 'name'))
        .not_to eq(second.reload.body.dig('variable', 'name'))
    end

    it 'does not raise when a sibling question has a variable-less body' do
      create(:question_finish, question_group: ra_question_group)
      question = question_with_variable(:question_single, '')

      expect { question.save! }.not_to raise_error
    end
  end

  describe 'rejecting a blank variable on update' do
    it 'is invalid when the variable is cleared' do
      question = create(:question_single, question_group: ra_question_group)
      body = question.body.deep_stringify_keys
      body['variable']['name'] = ''
      question.body = body

      expect(question.valid?).to be(false)
      expect(question.errors[:base]).to be_present
    end
  end

  describe 'non-answerable RA questions' do
    it 'leaves a Finish question untouched (no variable assigned)' do
      question = create(:question_finish, question_group: ra_question_group)
      expect(question.reload.body.key?('variable')).to be(false)
    end
  end

  describe 'non-RA (Classic) sessions' do
    it 'still allows a blank variable' do
      classic_group = create(:question_group, session: create(:session, intervention: intervention))
      question = question_with_variable(:question_single, '', group: classic_group)

      expect(question.save).to be(true)
      expect(question.reload.body.dig('variable', 'name')).to eq('')
    end
  end
end
