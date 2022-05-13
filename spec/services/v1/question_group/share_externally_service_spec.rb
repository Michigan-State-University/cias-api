# frozen_string_literal: true

RSpec.describe V1::QuestionGroup::ShareExternallyService do
  subject { described_class.new(researcher_ids, source_session_id, selected_groups_with_questions, current_user) }

  let!(:current_user) { create(:user, :researcher) }
  let!(:intervention) { create(:intervention, user_id: current_user.id) }
  let!(:session1) { create(:session, intervention: intervention) }
  let!(:session2) { create(:session, intervention: intervention) }
  let!(:researcher) { create(:user, :researcher) }

  let!(:question_group) { create(:question_group, session: session1, type: 'QuestionGroup::Plain') }
  let!(:question1) { create(:question_single, question_group: question_group) }
  let!(:question2) { create(:question_multiple, question_group: question_group) }
  let!(:question3) { create(:question_feedback, question_group: question_group) }

  let!(:selected_groups_with_questions) do
    [
      { 'id' => question_group.id, 'question_ids' => [question1.id, question3.id] }
    ]
  end
  let!(:researcher_ids) do
    [
      researcher.id
    ]
  end
  let!(:source_session_id) { session1.id }

  it 'all params are valid' do
    expect { subject.call }.to change(QuestionGroup, :count).by(2).and change(Session, :count).by(1).and change(Intervention, :count).by(1)
  end

  context 'when user hasn\'t correct ability' do
    let!(:participant) { create(:user, :participant) }
    let!(:researcher_ids) do
      [
        researcher.id, participant.id
      ]
    end

    it 'raise exception' do
      expect { subject.call }.to raise_error(CanCan::AccessDenied)
    end
  end
end
