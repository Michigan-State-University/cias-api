# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clone::Session, type: :model do
  describe 'CIAS-4161 - cloning a session that contains a finish question' do
    # A Session::Classic auto-creates a QuestionGroup::Finish + Question::Finish via an
    # after_commit callback (see Session::ClassicBehavior#create_core_children), so cloning
    # a session always clones a Question::Finish whose `position` is attr_readonly.
    #
    # Without the fix, re-assigning the readonly position during the internal question clones
    # raises ActiveRecord::ReadonlyAttributeError (raise_on_assign_to_attr_readonly is enabled
    # via load_defaults 7.1), the question group transaction rolls back, and the clone ends up
    # with none of its questions. The existing job specs miss this because CloneJobs::Session
    # rescues StandardError and only assert session/email counts; here we call #clone directly
    # so the error surfaces, and assert the question count is preserved.
    let(:intervention) { create(:intervention) }
    let(:session) { create(:session, intervention: intervention) }
    let!(:question_group) { create(:question_group, session: session, position: 1) }
    let!(:question1) { create(:question_single, question_group: question_group, position: 1) }
    let!(:question2) { create(:question_single, question_group: question_group, position: 2) }

    def question_count_for(session_id)
      Question.unscoped.joins(:question_group)
              .where(question_groups: { session_id: session_id }).count
    end

    it 'clones every question without dropping any' do
      source_count = question_count_for(session.id)
      expect(source_count).to be_positive
      finish_present = Question.unscoped.joins(:question_group)
                               .exists?(question_groups: { session_id: session.id }, type: 'Question::Finish')
      expect(finish_present).to be(true)

      cloned = nil
      expect do
        cloned = session.clone(params: { variable: 'cloned_session_var' }, clean_formulas: false, position: 99)
      end.not_to raise_error

      expect(question_count_for(cloned.id)).to eq(source_count)
    end
  end
end
