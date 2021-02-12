# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/question_groups/:question_group_id/questions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question_group) { create(:question_group) }
  let(:question) { create(:question_slider, question_group: question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      question: {
        type: question.type,
        position: 999,
        title: 'Question Test 1',
        subtitle: 'test 1',
        body: {
          data: [
            {
              payload: {
                start_value: 'test 1',
                end_value: 'test 1'
              }
            }
          ],
          "variable": {
            "name": 'var test 1'
          }
        }
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id), params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id), params: params, headers: headers
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key question' do
        expect(json_response['data']['type']).to eq('question')
      end
    end
  end
end
