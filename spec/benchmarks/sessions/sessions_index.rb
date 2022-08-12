# frozen_string_literal: true

require 'benchmark/ips'

RSpec.describe 'Benchmark', type: :request do
  context 'Sessions' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }
    let!(:intervention) { create(:intervention, :published, user_id: user.id) }
    let!(:session) { create(:session, intervention_id: intervention.id) }

    it 'give a proper benchmark' do
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)

        x.report('GET Sessions') { get v1_intervention_sessions_path(intervention.id), headers: headers }
      end
    end
  end
end
