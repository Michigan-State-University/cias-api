# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/question_groups/:question_group_id/questions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question_group) { create(:question_group) }
  let(:question) { create(:question_slider, question_group: question_group) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { delete v1_question_group_question_path(question_group_id: question_group.id, id: question.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { delete v1_question_group_question_path(question_group_id: question_group.id, id: question.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is success' do
      before do
        delete v1_question_group_question_path(question_group_id: question_group.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:no_content) }
    end
  end
end
