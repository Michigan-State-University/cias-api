# frozen_string_literal: true

RSpec.describe 'GET /v1/user_sessions/:user_session_id/user_answers', type: :request do
  let(:answers_response) { json_response['data'].all? { |hash| answers.any? { |a| a.id == hash['id'] } } }

  let(:request) do
    get v1_user_session_user_answers_path(user_session.id), headers: headers
  end

  context 'authorized access' do
    %i[e_intervention_admin researcher team_admin].each do |role|
      context "user session for role #{role} has answers" do
        let!(:user) { create(:user, :confirmed, role) }
        let!(:intervention) { create(:intervention, user_id: user.id) }
        let!(:session) { create(:session, intervention_id: intervention.id) }
        let!(:user_session) { create(:user_session, session: session) }
        let!(:question_group) { create(:question_group, session: session) }
        let!(:questions) { create_list(:question_single, 5, question_group: question_group) }
        let!(:answers) { questions.map { |q| create(:answer_single, user_session_id: user_session.id, question: q) } }
        let(:headers) { user.create_new_auth_token }

        before { request }

        it 'returns correct amount of answers' do
          expect(json_response['data'].size).to eq(answers.size)
        end

        it 'returns correct answers' do
          expect(answers_response).to eq(true)
        end

        it 'returns correct response code' do
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  context 'unauthorized access' do
    %i[participant guest].each do |role|
      let!(:user) { create(:user, :confirmed, role) }
      let!(:intervention) { create(:intervention, user_id: user.id) }
      let!(:session) { create(:session, intervention_id: intervention.id) }
      let!(:user_session) { create(:user_session, session: session, user_id: user.id) }
      let!(:question_group) { create(:question_group, session: session) }
      let!(:questions) { create_list(:question_single, 5, question_group: question_group) }
      let!(:answers) { questions.map { |q| create(:answer_single, user_session: user_session, question: q) } }
      let(:headers) { user.create_new_auth_token }

      before { request }

      it "returns 403 (Forbidden) for user #{role}" do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
