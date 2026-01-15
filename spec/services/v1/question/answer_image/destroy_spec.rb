# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Question::AnswerImage::Destroy do
  subject(:perform_service) { described_class.call(question, answer_id) }

  let(:question_group) { create(:question_group) }
  let(:answer_id) { 'answer_1' }
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
    question.answer_images.attach(blob)
    question.body['data'][0]['image_id'] = blob.attachment_ids.first
    question.save!
    question.answer_images.joins(:blob)
            .find_by("(active_storage_blobs.metadata::jsonb)->>'answer_id' = ?", answer_id)
  end

  describe 'when params are valid' do
    it 'purges the image from the question' do
      expect { perform_service }.to change { question.answer_images.count }.by(-1)
    end

    it 'removes image_id from the answer in question body' do
      perform_service
      question.reload
      answer_index = question.body['data'].find_index { |answer| answer['id'] == answer_id }
      expect(question.body['data'][answer_index]['image_id']).to be_nil
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
        question.answer_images.attach(blob)
        question.body['data'][1]['image_id'] = blob.attachment_ids.first
        question.save!
        question.answer_images.joins(:blob)
                .find_by("(active_storage_blobs.metadata::jsonb)->>'answer_id' = ?", answer_id)
      end

      it 'purges the correct answer image' do
        expect(question.body['data'][1]['image_id']).to be_present
        perform_service
        question.reload
        expect(question.body['data'][1]['image_id']).to be_nil
      end
    end

    context 'when multiple answers have images' do
      let(:file2) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }

      before do
        blob2 = ActiveStorage::Blob.create_and_upload!(
          io: file2,
          filename: file2.original_filename,
          content_type: file2.content_type,
          metadata: { answer_id: 'answer_2' }
        )
        question.answer_images.attach(blob2)
        question.body['data'][1]['image_id'] = blob2.attachment_ids.first
        question.save!
      end

      it 'only purges the specified answer image' do
        expect { perform_service }.to change { question.answer_images.count }.by(-1)
      end

      it 'keeps the other answer images intact' do
        perform_service
        question.reload
        expect(question.body['data'][0]['image_id']).to be_nil
        expect(question.body['data'][1]['image_id']).to be_present
      end
    end
  end

  describe 'when params are invalid' do
    context 'when answer_id does not exist in question body' do
      let(:answer_id) { 'non_existent_answer' }

      it 'raises ArgumentError' do
        expect { perform_service }.to raise_error(ArgumentError, 'Wrong answer_id')
      end

      it 'does not purge any image from the question' do
        expect do
          perform_service
        rescue StandardError
          nil
        end.not_to change { question.answer_images.count }
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
        question.body['data'][0].delete('image_id')
        question.save!
      end

      it 'raises ActiveRecord::RecordNotFound' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'does not change the question body' do
        expect do
          perform_service
        rescue StandardError
          nil
        end.not_to change { question.reload.body }
      end
    end

    context 'when answer exists but has no image_id in body' do
      before do
        existing_attachment.purge
        question.body['data'][0].delete('image_id')
        question.save!
      end

      it 'raises ActiveRecord::RecordNotFound' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
