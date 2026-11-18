# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/questions/:question_id/answer_images/:answer_id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:params) do
    {
      image: {
        image_alt: 'Updated alt text for answer image'
      }
    }
  end
  let(:request) { patch v1_question_update_answer_image_path(question.id, answer_id), params: params, headers: headers }
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
  let(:headers) { user.create_new_auth_token }

  before do
    file = FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: file.original_filename,
      content_type: file.content_type,
      metadata: { answer_id: answer_id }
    )
    question.answer_images.attach(blob)
    question.body['data'][0]['image_id'] = blob.attachment_ids.first
    question.save!
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_question_update_answer_image_path(question.id, answer_id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is appropriate Content-Type' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is success' do
      before { request }

      it { expect(response).to have_http_status(:ok) }

      it 'returns question with updated image_alt in answer' do
        expect(json_response['data']['type']).to eq('question')
        alt_text = json_response['data']['attributes']['answer_images'][0]['alt']
        expect(alt_text).to eq('Updated alt text for answer image')
      end
    end
  end
end
