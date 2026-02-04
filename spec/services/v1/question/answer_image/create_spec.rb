# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Question::AnswerImage::Create do
  subject(:perform_service) { described_class.call(question, answer_id, file) }

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

  describe 'when params are valid' do
    it 'attaches the image to the question' do
      expect { perform_service }.to change { question.answer_images.count }.by(1)
    end

    it 'stores the answer_id in blob metadata' do
      perform_service
      attachment = question.reload.answer_images.last
      expect(attachment.metadata['answer_id']).to eq(answer_id)
    end

    it 'assigns image_id to the correct answer in question body' do
      result = perform_service
      answer_index = question.body['data'].find_index { |answer| answer['id'] == answer_id }
      expect(result.body['data'][answer_index]['image_id']).to be_present
    end

    context 'when answer_id is for the second answer' do
      let(:answer_id) { 'answer_2' }

      it 'assigns image_id to the correct answer' do
        result = perform_service
        expect(result.body['data'][0]['image_id']).to be_nil
        expect(result.body['data'][1]['image_id']).to be_present
      end
    end

    context 'when answer already has answer images' do
      let!(:existing_file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }

      before do
        answer_id = 'answer_1'
        blob = ActiveStorage::Blob.create_and_upload!(
          io: existing_file,
          filename: existing_file.original_filename,
          content_type: existing_file.content_type,
          metadata: { answer_id: answer_id }
        )
        question.answer_images.attach(blob)
        question.body['data'][0]['image_id'] = blob.attachment_ids.first
        question.save!
      end

      it 'raises exception' do
        expect { perform_service }.to raise_error(ActiveRecord::RecordNotSaved)
      end
    end
  end

  describe 'when params are invalid' do
    context 'when answer_id does not exist in question body' do
      let(:answer_id) { 'non_existent_answer' }

      it 'raises ArgumentError' do
        expect { perform_service }.to raise_error(ArgumentError, 'Wrong answer_id')
      end

      it 'does not attach any image to the question' do
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
  end
end
