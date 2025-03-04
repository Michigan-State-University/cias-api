# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/question_groups #show' do
    let!(:admin) { create(:user, :confirmed, :admin) }
    let!(:headers) { admin.create_new_auth_token }
    let!(:session) { create(:session) }
    let!(:small_question_group) { create(:question_group, session: session) }
    let!(:large_question_group) { create(:question_group, session: session) }
    let!(:small_questions) { create_list(:question_single, 25, question_group: small_question_group) }
    let!(:large_questions) { create_list(:question_single, 50, question_group: large_question_group) }

    it 'gives a proper benchmark' do
      puts "\nEndpoint: v1/question_groups #show"
      expect do
        Benchmark.ips do |x|
          x.config(time: 5, warmup: 2)

          x.report('GET 25 Questions') { get v1_session_question_group_path(session_id: session.id, id: small_question_group.id), headers: headers }
          x.report('GET 50 Questions') { get v1_session_question_group_path(session_id: session.id, id: large_question_group.id), headers: headers }

          x.compare!
        end
      end.not_to raise_error
    end
  end
end
