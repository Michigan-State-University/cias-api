# frozen_string_literal: true

RSpec.describe V1::QuestionService do
  describe '.clone_multiple' do
    subject { described_class.new(user) }

    let(:user) { create(:user, :confirmed, :admin) }
    let(:session) { create(:session, intervention: create(:intervention, user: user)) }
    let!(:question_group) { create(:question_group_plain, title: 'Question Group Title', position: 1, session: session) }
    let!(:question_group_2) { create(:question_group_plain, title: 'Question Group 2 Title', position: 2, session: session) }

    let!(:questions) { create_list(:question_single, 3, title: 'Question Id Title', question_group: question_group) }
    let!(:questions_2) { create_list(:question_slider, 3, title: 'Question 2 Id Title', question_group: question_group_2) }
    let(:question_ids) { questions.pluck(:id) }

    context 'questions are from one question group' do
      let(:result) { subject.clone_multiple(session.id, question_ids) }

      it 'returns list of cloned questions' do
        expect(result[0].attributes).to include({ 'title' => questions.last.title,
                                                  'position' => questions.last.position + 1,
                                                  'question_group_id' => questions.last.question_group_id })
        expect(result[1].attributes).to include({ 'title' => questions.last.title,
                                                  'position' => questions.last.position + 2,
                                                  'question_group_id' => questions.last.question_group_id })
        expect(result[2].attributes).to include({ 'title' => questions.last.title,
                                                  'position' => questions.last.position + 3,
                                                  'question_group_id' => questions.last.question_group_id })
      end

      it 'returns proper number of questions' do
        expect(result.size).to eq(question_ids.size)
      end
    end

    context 'questions are from different question groups' do
      let(:question_ids) { [questions.first.id, questions_2.first.id] }
      let(:copied_questions) { Question.where(id: question_ids) }
      let(:result) { subject.clone_multiple(session.id, question_ids) }

      it 'returns list of cloned questions' do
        expect(result[0].attributes).to include({ 'title' => copied_questions[0].title,
                                                  'position' => 1,
                                                  'question_group_id' => session.question_groups.reload.last(2).first.id })
        expect(result[1].attributes).to include({ 'title' => copied_questions[1].title,
                                                  'position' => 2,
                                                  'question_group_id' => session.question_groups.reload.last(2).first.id })
      end

      it 'returns proper number of questions' do
        expect(result.size).to eq(question_ids.size)
      end
    end

    context 'when input parameters are improper' do
      let(:result) do
        subject.clone_multiple(session_id, question_ids)
      rescue StandardError => e
        e.message
      end

      context 'when session_id is invalid' do
        let!(:session_id) { 'invalid' }

        it 'raises proper error message' do
          expect(result).to eq("Couldn't find Session with 'id'=invalid")
        end
      end

      context 'question_ids is invalid' do
        context 'question_ids is empty' do
          let!(:session_id) { session.id }
          let!(:question_ids) { [] }

          it 'raises proper error message' do
            expect(result).to eq("Couldn't find QuestionGroup without an ID")
          end
        end

        context 'question_ids is null' do
          let!(:session_id) { session.id }
          let!(:question_ids) { nil }

          it 'raises proper error' do
            expect(result).to eq('ActiveRecord::RecordNotFound')
          end
        end
      end

      context 'specific question type can appear only once per session' do
        let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
        let!(:session_id) { session.id }
        let!(:question_group_1) { create(:question_group_plain, title: 'Question Group Title', position: 1, session: session) }
        let!(:question_group_2) { create(:question_group_plain, title: 'Question Group 2 Title', position: 2, session: session) }

        let!(:question) { create(:question_name, title: 'Name::Question', question_group: question_group_1) }
        let!(:question_2) { create(:question_name, title: 'Name::Question', question_group: question_group_2) }
        let(:question_ids) { [question.id] }

        let(:result) do
          subject.clone_multiple(session_id, question_ids)
        rescue StandardError => e
          e.message
        end

        it 'return warning when copied question is Question::Name' do
          expect(result).to eq('Question::Name can appear only once per session')
          expect(question_group_1.reload.questions.size).to be(1)
        end

        context 'one of questions is Question::Name' do
          let!(:question_3) { create(:question_single, title: 'Single::Question', question_group: question_group_2) }
          let(:question_ids) { [question.id, question_3.id] }

          it 'return appropriate message and not add Copied Questions' do
            expect(result).to eq('Question::Name can appear only once per session')
          end
        end
      end
    end
  end
end
