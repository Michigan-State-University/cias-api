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
        type: 'Question::ThirdParty',
        position: 99,
        title: 'Question Test 1',
        subtitle: 'test 1',
        body: {
          data: [
            payload: '',
            value: '',
            report_template_ids: []
          ],
          variable: { name: '' }
        }
      }
    }
  end

  context 'created' do
    before do
      post v1_question_group_questions_path(question_group.id), params: params, headers: headers, as: :json
    end

    it 'has correct body attributes' do
      expect(json_response['data']['attributes']['body']).to include('data' => ['payload' => '', 'value' => '', 'report_template_ids' => []])
    end
  end
end
