# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/question_groups/:question_group_id/questions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question_group) { create(:question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:blocks) { [] }
  let(:params) do
    {
      question: {
        type: 'Question::Slider',
        position: 99,
        title: 'Question Test 1',
        subtitle: 'test 1',
        body: {
          'data' => [
            { 'payload' => {
              'range_start' => 1,
              'range_end' => 10,
              'end_value' => '',
              'start_value' => ''
            } }
          ],
          'variable' => {
            'name' => 'slytherin'
          }
        }
      }
    }
  end

  context 'created' do
    before do
      post v1_question_group_questions_path(question_group.id), params: params, headers: headers, as: :json
    end

    it 'returns correct status' do
      expect(response).to have_http_status(:created)
    end

    it 'has correct body attributes' do
      expect(json_response['data']['attributes']['body']).to include('data' => ['payload' => {
                                                                       'range_start' => 1,
                                                                       'range_end' => 10,
                                                                       'end_value' => '',
                                                                       'start_value' => ''
                                                                     }],
                                                                     'variable' => { 'name' => 'slytherin' })
    end
  end

  context 'invalid arguments' do
    context 'range values not a number' do
      before do
        params[:question][:body]['data'][0]['payload']['range_start'] = 'griffindor'
        post v1_question_group_questions_path(question_group.id), params: params, headers: headers, as: :json
      end

      it 'returns correct status' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns correct error message' do
        expect(json_response['message']).to eq('Only numbers are permitted on the range endpoint')
      end
    end

    context 'range start larger than range end' do
      before do
        params[:question][:body]['data'][0]['payload']['range_start'] = 999
        post v1_question_group_questions_path(question_group.id), params: params, headers: headers, as: :json
      end

      it 'returns correct status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns correct error message' do
        expect(json_response['message']).to eq('Validation failed: End value must be larger than the start value')
      end
    end
  end
end
