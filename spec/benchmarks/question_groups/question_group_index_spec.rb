# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/question_groups #index' do
    let!(:admin) { create(:user, :confirmed, :admin) }
    let!(:headers) { admin.create_new_auth_token }
    let!(:small_session) { create(:session) }
    let!(:large_session) { create(:session) }
    let!(:small_question_groups) { create_list(:question_group, 25, session: small_session) }
    let!(:large_question_groups) { create_list(:question_group, 50, session: large_session) }

    it 'gives a proper benchmark' do
      puts "\nEndpoint: v1/question_groups #index"
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report('GET 25 QuestionGroups') { get v1_session_question_groups_path(session_id: small_session.id), headers: headers }
        x.report('GET 50 QuestionGroups') { get v1_session_question_groups_path(session_id: large_session.id), headers: headers }

        x.compare!
      end
    end
  end
end
