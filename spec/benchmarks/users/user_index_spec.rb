# frozen_string_literal: true

RSpec.describe 'Benchmark', type: :request do
  context 'v1/users #index' do
    let!(:admin) { create(:user, :confirmed, :admin, first_name: 'CIAS', last_name: 'Admin', email: 'cias.admin@test.com', created_at: 10.days.ago) }
    let!(:users) { create_list(:user, 50, :confirmed, :participant) }
    let!(:params_small) { { page: 1, per_page: 25 } }
    let!(:params_large) { { page: 1, per_page: 50 } }

    it 'gives a proper benchmark' do
      puts "\nEndpoint: v1/users #index"
      expect do
        Benchmark.ips do |x|
          Rails.logger.debug 'v1/users #index'
          x.config(time: 5, warmup: 2)

          x.report('GET 5 Users') { get v1_users_path, params: params_small, headers: admin.create_new_auth_token }
          x.report('GET 10 Users') { get v1_users_path, params: params_large, headers: admin.create_new_auth_token }

          x.compare!
        end
      end.not_to raise_error
    end
  end
end
