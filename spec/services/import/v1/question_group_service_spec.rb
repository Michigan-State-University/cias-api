# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::QuestionGroupService do
  subject { described_class.call(session_id, question_group_hash) }

  let(:question_group_hash) do
    {
      title: 'Group 1',
      position: 1,
      type: 'QuestionGroup::Plain',
      version: '1',
      questions: []
    }
  end

  let(:session_id) { create(:session).id }

  it 'create question group' do
    expect { subject }.to change(QuestionGroup, :count).by(2)
  end
end
