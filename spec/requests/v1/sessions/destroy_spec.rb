# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/sessions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:question_group) { create(:question_group_plain, session: session) }
  let!(:questions) { create_list(:question_single, 4, question_group: question_group) }
  let!(:answers) { create_list(:answer_single, 3, question: questions.first) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { delete v1_intervention_session_path(intervention_id: intervention.id, id: session.id) }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { delete v1_intervention_session_path(intervention_id: intervention.id, id: session.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end

      it 'session is deleted' do
        expect(Session.find_by(id: session.id)).to eq(nil)
      end

      it 'question_group is deleted' do
        expect(QuestionGroup.find_by(id: question_group.id)).to eq(nil)
      end

      it 'question is deleted' do
        expect(Question.find_by(id: questions.last.id)).to eq(nil)
      end

      it 'answer is deleted' do
        expect(Answer.find_by(id: answers.last.id)).to eq(nil)
      end
    end
  end

  context 'when intervention_id is invalid' do
    before do
      delete v1_intervention_session_path(intervention_id: 9000, id: session.id), headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when session_id is invalid' do
    before do
      delete v1_intervention_session_path(intervention_id: intervention.id, id: 9000), headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when all params are valid and response' do
    context 'is success' do
      before do
        delete v1_intervention_session_path(intervention_id: intervention.id, id: session.id), headers: headers
      end

      it { expect(response).to have_http_status(:no_content) }

      it 'session is deleted' do
        expect(Session.find_by(id: session.id)).to eq(nil)
      end

      it 'question_group is deleted' do
        expect(QuestionGroup.find_by(id: question_group.id)).to eq(nil)
      end

      it 'question is deleted' do
        expect(Question.find_by(id: questions.last.id)).to eq(nil)
      end

      it 'answer is deleted' do
        expect(Answer.find_by(id: answers.last.id)).to eq(nil)
      end
    end

    context 'is failure' do
      before do
        intervention.broadcast
        delete v1_intervention_session_path(intervention_id: intervention.id, id: session.id), headers: headers
      end

      it { expect(response).to have_http_status(:no_content) }

      it 'session is not deleted' do
        expect(Session.find(session.id)).to eq(session)
      end
    end
  end
end
