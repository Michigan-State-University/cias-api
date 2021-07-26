# frozen_string_literal: true

RSpec.describe V1::Question::Create do
  subject { described_class.call(questions_scope, question_params) }

  let(:question_group) { create(:question_group) }
  let!(:questions) { create_list(:question_single, 3, title: 'Question Id Title', question_group: question_group) }
  let(:question_group_load) { QuestionGroup.includes(:questions).find(question_group.id) }
  let(:questions_scope) { question_group_load.questions.order(:position) }
  let(:blocks) { [] }
  let(:question_params) do
    {
        type: 'Question::Multiple',
        position: 99,
        title: 'Question Test 1',
        subtitle: 'test 1',
        formula: {
          payload: 'test',
          patterns: [
            {
              match: '= 5',
              target: [{
                type: 'Session',
                probability: '100',
                id: ''
              }]
            },
            {
              match: '> 5',
              target: [{
                type: 'Question',
                probability: '100',
                id: ''
              }]
            }
          ]
        },
        body: {
          data: [
            {
              payload: 'create1',
              variable: {
                name: 'test1',
                value: '1'
              }
            },
            {
              payload: 'create2',
              variable: {
                name: 'test2',
                value: '2'
              }
            }
          ]
        },
        narrator: {
          blocks: blocks,
          settings: {
            voice: true,
            animation: true
          }
        }
    }
  end
  let(:last_question) { question_group.reload.questions.last }

  describe 'params are valid' do
    it 'question have right position' do
      subject
      expect(last_question.position).to eq(4)
    end

    it 'change question count by 1' do
      expect { subject }.to change(Question, :count).by(1)
    end
  end
end
