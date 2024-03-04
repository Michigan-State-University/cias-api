# frozen_string_literal: true

RSpec.describe V1::QuestionGroup::DuplicateWithStructureService do
  subject { described_class.new(target_session, selected_groups_with_questions) }

  let!(:intervention) { create(:intervention) }

  let!(:selected_groups_with_questions) do
    [
      { 'id' => question_group.id, 'question_ids' => [question1.id, question3.id] }
    ]
  end
  let!(:session1) { create(:session, intervention: intervention) }
  let!(:session2) { create(:session, intervention: intervention) }

  let!(:question_group) { create(:question_group, session: session1, type: 'QuestionGroup::Plain') }
  let!(:question1) { create(:question_single, question_group: question_group) }
  let!(:question2) { create(:question_multiple, question_group: question_group) }
  let!(:question3) { create(:question_feedback, question_group: question_group) }
  let!(:target_session) { session1 }

  it 'create a new group and selected question when all params are valid' do
    expect { subject.call }.to change(QuestionGroup, :count).by(1)
    created_question_group = session1.question_groups.find_by(position: 2)
    expect(created_question_group.title).to eql("Copy of #{question_group.title}")
    expect(created_question_group.questions.count).to be 2
    expect(created_question_group.questions.pluck(:type)).to include('Question::Single', 'Question::Feedback')
  end

  it 'return new groups' do
    result = subject.call
    expect(result).to be_a(Array)
    expect(result.size).to be 1
    expect(result.first.type).to eql('QuestionGroup::Plain')
  end

  context 'when at least one argument is invalid' do
    let!(:selected_groups_with_questions) { [] }

    it 'raise exception' do
      expect { subject.call }.to raise_error(ArgumentError)
    end
  end

  context 'when pass wrong question id' do
    let!(:selected_groups_with_questions) do
      [
        { 'id' => question_group.id, 'question_ids' => [question1.id, question3.id, 'wrong_id'] }
      ]
    end

    it 'raise exception' do
      expect { subject.call }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when question belongs to other group' do
    let!(:question) { create(:question_single) }
    let!(:selected_groups_with_questions) do
      [
        { 'id' => question_group.id, 'question_ids' => [question1.id, question3.id, question.id] }
      ]
    end

    it 'raise exception' do
      expect { subject.call }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when whe want duplicate uniq question per session' do
    let!(:question3) { create(:question_name, question_group: question_group) }

    it 'raise exception' do
      expect { subject.call }.to raise_error(ArgumentError)
    end

    context 'henry ford health - initial screen and default intervention don\'t have access to HFHS -> initial screen should be skipped' do
      let(:intervention) { create(:intervention) }
      let!(:target_session) { create(:session, intervention: intervention) }
      let!(:question3) { create(:question_henry_ford_initial_screen, question_group: question_group) }
      let(:selected_groups_with_questions) do
        [
          { 'id' => question_group.id, 'question_ids' => [question1.id, question3.id] }
        ]
      end

      it 'returns only one question' do
        expect(subject.call.first.questions_count).to eq 1
      end

      context 'invalid duplication of only henry ford health - initial screen' do
        let(:selected_groups_with_questions) do
          [
            { 'id' => question_group.id, 'question_ids' => [question3.id] }
          ]
        end

        it 'raises exception' do
          expect { subject.call }.to raise_error(ArgumentError)
        end
      end
    end

    context 'henry ford health - two initial screen' do
      let!(:intervention) { create(:intervention, hfhs_access: true) }
      let!(:question3) { create(:question_henry_ford_initial_screen, question_group: question_group) }

      it 'raise exception' do
        expect { subject.call }.to raise_error(ArgumentError)
      end
    end
  end
end
