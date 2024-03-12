# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/interventions #index' do
    let!(:admin) { create(:user, :confirmed, :admin) }
    let!(:params_long) { { start_index: 0, end_index: 49 } }
    let!(:params_short) { { start_index: 0, end_index: 24 } }
    let!(:headers) { admin.create_new_auth_token }
    let!(:interventions) { create_list(:intervention, 50, :published, user_id: admin.id) }

    it 'gives a proper benchmark' do
      puts "\nEndpoint: v1/interventions #index"
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report('GET 50 Interventions') { get v1_interventions_path, params: params_long, headers: headers }
        x.report('GET 25 Interventions') { get v1_interventions_path, params: params_short, headers: headers }

        x.compare!
      end
    end
  end
end
