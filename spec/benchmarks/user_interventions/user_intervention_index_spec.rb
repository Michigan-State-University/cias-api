# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/user_interventions #index' do
    let!(:admin) { create(:user, :confirmed, :admin, first_name: 'CIAS', last_name: 'Admin', email: 'cias.admin@test.com', created_at: 10.days.ago) }
    let(:participant1) { create(:user, :confirmed, :participant) }
    let(:headers) { admin.create_new_auth_token }

    let(:intervention) { create(:intervention) }
    let!(:sessions) { create_list(:session, 5, intervention_id: intervention.id) }

    let!(:user_interventions) { create_list(:user_intervention, 50, intervention: intervention, status: 'completed') }

    let!(:params_small) { { start_index: 0, end_index: 24 } }
    let!(:params_large) { { start_index: 0, end_index: 49 } }

    it 'gives a proper benchmark' do
      puts "\nEndpoint: v1/user_interventions #index"
      expect do
        Benchmark.ips do |x|
          x.config(time: 5, warmup: 2)

          x.report('GET 25 User Interventions') { get v1_user_interventions_path, params: params_small, headers: headers }
          x.report('GET 50 User Interventions') { get v1_user_interventions_path, params: params_large, headers: headers }

          x.compare!
        end
      end.not_to raise_error
    end
  end
end
