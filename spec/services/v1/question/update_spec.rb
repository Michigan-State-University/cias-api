# frozen_string_literal: true

RSpec.describe V1::Question::Update do
  subject { described_class.call(question, params) }

  let(:question_group) { create(:question_group) }
  let(:question) { create(:question_slider, question_group: question_group) }
  let(:params) do
    {
      title: 'New title',
      subtitle: 'new subtitle'
    }
  end

  describe 'params are valid' do
    before do
      subject
    end

    it 'update question' do
      expect(question.reload.title).to eq('New title')
      expect(question.reload.subtitle).to eq('new subtitle')
    end
  end

  describe 'params are invalid' do
    let(:params) do
      {
        title: '',
        subtitle: 'new subtitle'
      }
    end

    it 'raise an exception' do
      expect { subject }.to raise_exception(ActiveRecord::RecordInvalid)
    end
  end
end
