# frozen_string_literal: true

RSpec.shared_context 'with intervention serializers cached in Redis' do |serializers|
  let(:cache) do
    ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
                                              namespace: "spec-stars-#{SecureRandom.hex(6)}")
  end

  around do |example|
    example.run
  ensure
    cache.clear
  end

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    serializers.each { |serializer| allow(serializer).to receive(:cache_store_instance).and_return(cache) }
  end

  def starred_on_list(user)
    get v1_interventions_path, params: { start_index: 0, end_index: 50 }, headers: user.create_new_auth_token
    expect(response).to have_http_status(:ok)
    json_response['data'].find { |item| item['id'] == intervention.id }['attributes']['starred']
  end
end
