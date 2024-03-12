# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/interventions/answers #index' do
    let!(:admin) { create(:user, :confirmed, :admin) }
    let!(:headers) { admin.create_new_auth_token }
    let!(:small_intervention) { create(:intervention, user: admin) }
    let!(:small_session) { create(:session, intervention: small_intervention) }
    let!(:small_question_group) { create(:question_group, session: small_session) }
    let!(:small_question) { create(:question_single, question_group: small_question_group) }
    let!(:small_answers) { create_list(:answer_single, 25, question: small_question) }

    let!(:large_intervention) { create(:intervention, user: admin) }
    let!(:large_session) { create(:session, intervention: large_intervention) }
    let!(:large_question_group) { create(:question_group, session: large_session) }
    let!(:large_question) { create(:question_single, question_group: large_question_group) }
    let!(:large_answers) { create_list(:answer_single, 50, question: large_question) }

    it 'gives a proper benchmark' do
      puts "\nEndpoint: v1/interventions/answers #index"
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report('GET 25 Answers') { get v1_intervention_answers_path(small_intervention.id), headers: headers }
        x.report('GET 50 Answers') { get v1_intervention_answers_path(large_intervention.id), headers: headers }

        x.compare!
      end
    end
  end
end
