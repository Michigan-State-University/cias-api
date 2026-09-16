# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Question::AnswerImage::Update do
  subject(:perform_service) { described_class.call(question, answer_id, image_alt) }

  let(:question_group) { create(:question_group) }
  let(:answer_id) { 'answer_1' }
  let(:image_alt) { 'Updated alt text for the image' }
  let(:question) do
    create(:question_multiple, question_group: question_group, body: {
             'data' => [
               { 'id' => 'answer_1', 'payload' => 'Option 1', 'variable' => { 'name' => 'var1', 'value' => '1' } },
               { 'id' => 'answer_2', 'payload' => 'Option 2', 'variable' => { 'name' => 'var2', 'value' => '2' } }
             ]
           })
  end
  let(:file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }

  let!(:existing_attachment) do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: file.original_filename,
      content_type: file.content_type,
      metadata: { answer_id: answer_id }
    )
    blob.update!(description: 'Original alt text')
    question.answer_images.attach(blob)
    question.answer_images.joins(:blob)
            .find_by("(active_storage_blobs.metadata::jsonb)->>'answer_id' = ?", answer_id)
  end

  describe 'when params are valid' do
    it 'updates the image alt text' do
      perform_service
      expect(existing_attachment.blob.reload.description).to eq(image_alt)
    end

    it 'returns the question' do
      result = perform_service
      expect(result).to eq(question)
    end

    context 'when answer_id is for the second answer' do
      let(:answer_id) { 'answer_2' }
      let(:file2) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }

      let!(:existing_attachment) do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file2,
          filename: file2.original_filename,
          content_type: file2.content_type,
          metadata: { answer_id: answer_id }
        )
        blob.update!(description: 'Original alt text for answer 2')
        question.answer_images.attach(blob)
        question.answer_images.joins(:blob)
                .find_by("(active_storage_blobs.metadata::jsonb)->>'answer_id' = ?", answer_id)
      end

      it 'updates the correct answer image' do
        perform_service
        expect(existing_attachment.blob.reload.description).to eq(image_alt)
      end
    end

    context 'when image_alt is blank' do
      let(:image_alt) { '' }

      it 'updates to blank description' do
        perform_service
        expect(existing_attachment.blob.reload.description).to eq('')
      end
    end

    context 'when image_alt is nil' do
      let(:image_alt) { nil }

      it 'updates to nil description' do
        perform_service
        expect(existing_attachment.blob.reload.description).to be_nil
      end
    end
  end

  describe 'when params are invalid' do
    context 'when answer_id does not exist in question body' do
      let(:answer_id) { 'non_existent_answer' }

      it 'raises ArgumentError' do
        expect { perform_service }.to raise_error(ArgumentError, 'Wrong answer_id')
      end
    end

    context 'when answer_id is nil' do
      let(:answer_id) { nil }

      it 'raises ArgumentError' do
        expect { perform_service }.to raise_error(ArgumentError, 'Wrong answer_id')
      end
    end

    context 'when answer_id is blank' do
      let(:answer_id) { '' }

      it 'raises ArgumentError' do
        expect { perform_service }.to raise_error(ArgumentError, 'Wrong answer_id')
      end
    end

    context 'when answer has answer_id but no attachment' do
      before do
        existing_attachment.purge
      end

      it 'raises ActiveRecord::RecordNotFound' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
