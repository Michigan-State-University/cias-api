# frozen_string_literal: true

RSpec.describe V1::QuestionGroup::ShareInternallyService do
  subject { described_class.new(target_sessions, selected_groups_with_questions) }

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
  let!(:target_sessions) do
    [
      session2
    ]
  end

  it 'all params are valid' do
    expect { subject.call }.to change(QuestionGroup, :count).by(1)
    expect { subject.call }.not_to change(Session, :count)
    expect { subject.call }.not_to change(Intervention, :count)
  end
end
