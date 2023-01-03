# frozen_string_literal: true

RSpec.describe 'GET /v1/sessions/:id/reflectable_questions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group1) { create(:question_group, session: session) }
  let(:question_group2) { create(:question_group, session: session) }
  let!(:questions) do
    [
      create(:question_single, question_group: question_group1),
      create(:question_multiple, question_group: question_group1),
      create(:question_grid, question_group: question_group2),
      create(:question_feedback, question_group: question_group2)
    ]
  end
  let(:request) do
    get v1_fetch_reflectable_questions_path(id: session.id), headers: headers
  end

  before { request }

  context 'return only reflectable question in correct format' do
    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct amount of data' do
      expect(json_response['data'].size).to eq(3)
    end

    it 'result contains expected question' do
      expect(json_response['data'].pluck('id')).to contain_exactly(questions[0].id, questions[1].id, questions[2].id)
    end

    it 'return only specific attributes' do
      keys = %w[type question_group_id subtitle body session_id]
      expect(json_response['data'].first['attributes'].keys).to(contain_exactly(*keys))
    end
  end
end
