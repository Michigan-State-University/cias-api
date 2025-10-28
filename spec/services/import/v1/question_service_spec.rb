# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::QuestionService do
  subject { described_class.call(question_group_id, question_hash) }

  let(:question_hash) do
    {
      type: 'Question::Single',
      settings: {
        image: false,
        title: true,
        video: false,
        required: true,
        subtitle: true,
        proceed_button: true,
        narrator_skippable: false
      },
      position: 1,
      title: 'Test',
      subtitle: 'Test',
      narrator: {
        blocks: [],
        settings: {
          voice: true,
          animation: true,
          character: 'peedy'
        }
      },
      video_url: nil,
      formulas: [],
      body: {
        data: [
          { value: '1', payload: '' }
        ],
        variable:
          {
            name: ''
          }
      },
      original_text:
        { title: '',
          subtitle: '',
          image_description: '' },
      duplicated: true,
      image: nil,
      version: '1'
    }
  end

  let(:question_group_id) { create(:question_group).id }

  it 'create question' do
    expect { subject }.to change(Question, :count).by(2)
  end

  context 'with image' do
    let(:question_hash) do
      super().merge(
        {
          image: {
            file: Base64.encode64('fake_image_data'),
            content_type: 'image/png',
            extension: 'png',
            description: 'Test image'
          }
        }
      )
    end

    it 'attach image to question' do
      question = subject
      expect(question.image).to be_attached
      expect(ActiveStorage::Blob.service.exist?(question.image.blob.key)).to be true
      expect(question.image_blob.description).to eq('Test image')
    end
  end
end
