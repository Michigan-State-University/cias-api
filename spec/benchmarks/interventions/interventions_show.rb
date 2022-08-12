# frozen_string_literal: true

require 'benchmark/ips'

RSpec.describe 'Benchmark', type: :request do
  context 'Intervention' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }

    let!(:sessions_long) { create_list(:session, 50) }
    let!(:intervention_long) { create(:intervention, :published, user_id: user.id, sessions: sessions_long) }

    let!(:sessions_short) { create_list(:session, 25) }
    let!(:intervention_short) { create(:intervention, :published, user_id: user.id, sessions: sessions_short) }

    it 'give a proper benchmark' do
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report('GET 50 Sessions from Intervention') { get v1_intervention_path(intervention_long.id), headers: headers }
        x.report('GET 25 Sessions from Intervention') { get v1_intervention_path(intervention_short.id), headers: headers }

        x.compare!
      end
    end
  end
end
