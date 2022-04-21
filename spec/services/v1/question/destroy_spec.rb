# frozen_string_literal: true

RSpec.describe V1::Question::Destroy do
  subject { described_class.call(questions, question_ids) }

  let(:question_group) { create(:question_group) }
  let!(:questions) { create_list(:question_single, 3, title: 'Question Id Title', question_group: question_group) }
  let(:question_ids) { questions.pluck(:id) }

  describe 'params are valid' do
    it 'delete all questions' do
      expect { subject }.to change(Question, :count).by(-3)
    end
  end

  describe 'params are invalid' do
    let(:question_ids) { questions.pluck(:id) << 'wrong_id' }

    it 'raise an exception' do
      expect { subject }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
