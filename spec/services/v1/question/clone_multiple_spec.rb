# frozen_string_literal: true

RSpec.describe V1::Question::CloneMultiple do
  subject { described_class.call(question_ids, chosen_questions) }

  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session, intervention: create(:intervention, user: user)) }
  let!(:question_group) { create(:question_group_plain, title: 'Question Group Title', position: 1, session: session) }
  let!(:questions) { create_list(:question_single, 3, title: 'Question Id Title', question_group: question_group) }
  let(:question_ids) { questions.pluck(:id) }
  let(:chosen_questions) { Question.where(id: question_ids) }

  context 'when params are valid' do
    it 'clone questions to the same group as original' do
      expect { subject }.to change(question_group.questions, :count).by(3)
    end

    describe 'return proper date' do
      let(:result) { described_class.call(question_ids, chosen_questions) }

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
    end

    context 'when questions belongs to different group' do
      let!(:question_group2) do
        create(:question_group_plain, title: 'Question Group 2 Title', position: 2, session: session)
      end
      let!(:questions2) { create_list(:question_single, 3, title: 'Question Id Title', question_group: question_group2) }
      let(:question_ids) { questions.pluck(:id) + questions2.pluck(:id) }
      let(:chosen_questions) { Question.where(id: question_ids) }

      it 'create new group' do
        expect { subject }.to change(session.question_groups, :count).by(1)
      end
    end
  end

  context 'when params are invalid' do
    let(:question_ids) { questions.pluck(:id) << 'wrong_id' }

    it 'raise an exception' do
      expect { subject }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end

  context 'specific question type can appear only once per session' do
    let!(:question) { create(:question_name, title: 'Name::Question', question_group: question_group) }
    let(:question_ids) { question_group.questions.pluck(:id) }
    let(:chosen_questions) { question_group.questions }

    let(:result) do
      subject.clone_multiple(session_id, question_ids)
    rescue StandardError => e
      e.message
    end

    it 'return warning when copied question is Question::Name' do
      expect(result).to eq('Question::Name can appear only once per session')
      expect(question_group.reload.questions.size).to be(4)
    end
  end
end
