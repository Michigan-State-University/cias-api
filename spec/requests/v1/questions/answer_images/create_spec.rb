# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answer_images', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question_group) { create(:question_group) }
  let(:question) do
    create(:question_multiple, question_group: question_group, body: {
             'data' => [
               { 'id' => 'answer_1', 'payload' => 'Option 1', 'variable' => { 'name' => 'var1', 'value' => '1' } },
               { 'id' => 'answer_2', 'payload' => 'Option 2', 'variable' => { 'name' => 'var2', 'value' => '2' } }
             ]
           })
  end
  let(:headers) do
    user.create_new_auth_token.
      merge({ 'Content-Type' => 'multipart/form-data; boundary=something' })
  end
  let(:params) do
    {
      image: {
        answer_id: 'answer_1',
        file: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
      }
    }
  end
  let(:request) { post v1_question_answer_images_path(question.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_question_answer_images_path(question.id) }

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

      it { expect(response).to have_http_status(:created) }

      it 'returns question with image_id in answer' do
        expect(json_response['data']['type']).to eq('question')
        answer_with_image = json_response['data']['attributes']['body']['data'].find { |a| a['id'] == 'answer_1' }
        expect(answer_with_image['image_id']).to be_present
      end
    end
  end
end
