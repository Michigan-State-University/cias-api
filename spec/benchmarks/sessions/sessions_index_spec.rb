# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/sessions #index' do
    let!(:admin) { create(:user, :confirmed, :admin) }
    let!(:headers) { admin.create_new_auth_token }
    let!(:small_intervention) { create(:intervention, :published, user_id: admin.id) }
    let!(:large_intervention) { create(:intervention, :published, user_id: admin.id) }
    let!(:small_sessions) { create_list(:session, 25, intervention_id: small_intervention.id) }
    let!(:large_sessions) { create_list(:session, 50, intervention_id: large_intervention.id) }

    it 'give a proper benchmark' do
      puts "\nEndpoint: v1/sessions #index"
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report('GET 25 Sessions') { get v1_intervention_sessions_path(small_intervention.id), headers: headers }
        x.report('GET 50 Sessions') { get v1_intervention_sessions_path(large_intervention.id), headers: headers }

        x.compare!
      end
    end
  end
end
