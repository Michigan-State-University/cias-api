# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/question_groups/:question_group_id/questions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question_group) { create(:question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      question: {
        type: 'Question::Multiple',
        position: 99,
        title: 'Question Test 1',
        subtitle: 'test 1',
        formula: {
          payload: 'test',
          patterns: [
            {
              match: '= 5',
              target: {
                type: 'Session',
                id: ''
              }
            },
            {
              match: '> 5',
              target: {
                type: 'Question',
                id: ''
              }
            }
          ]
        },
        body: {
          data: [
            {
              payload: 'create1',
              variable: {
                name: 'test1',
                value: '1'
              }
            },
            {
              payload: 'create2',
              variable: {
                name: 'test2',
                value: '2'
              }
            }
          ]
        }
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { post v1_question_group_questions_path(question_group.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_question_group_questions_path(question_group.id), params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        post v1_question_group_questions_path(question_group.id), params: params, headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        post v1_question_group_questions_path(question_group.id), params: params, headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end
  end
end
