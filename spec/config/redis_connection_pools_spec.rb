# frozen_string_literal: true

require 'sidekiq/api'

# The test environment uses :null_store and the :test job adapter, so nothing else exercises the
# connection_pool-backed Redis clients used in development/production. These examples build them
# against the real test Redis to catch breaking upgrades of connection_pool, sidekiq or redis-client.
RSpec.describe ConnectionPool do
  let(:redis_url) { ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }

  describe 'Rails cache store' do
    # Same options as config.cache_store in config/environments/production.rb
    let(:store) do
      ActiveSupport::Cache.lookup_store(:redis_cache_store, url: redis_url, driver: :ruby, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
                                                            pool: { size: 2, timeout: 1 })
    end
    let(:key) { "redis_connection_pools_spec:#{SecureRandom.hex(8)}" }

    after { store.delete(key) }

    it 'keeps its Redis clients in a connection pool' do
      expect(store.redis).to be_a(described_class)
    end

    it 'writes, reads and deletes values' do
      store.write(key, { 'answer' => 42 })

      expect(store.read(key)).to eq({ 'answer' => 42 })
      expect(store.delete(key)).to be(true)
      expect(store.read(key)).to be_nil
    end

    it 'serves more threads than the pool size' do
      results = Array.new(5) { |i| Thread.new { store.increment(key) && i } }.map(&:value) # rubocop:disable ThreadSafety/NewThread

      expect(results).to contain_exactly(0, 1, 2, 3, 4)
      expect(store.read(key, raw: true).to_i).to eq(5)
    end
  end

  describe 'Sidekiq client' do
    let(:queue_name) { "redis_connection_pools_spec_#{SecureRandom.hex(4)}" }

    after { Sidekiq::Queue.new(queue_name).clear }

    it 'keeps its Redis clients in a connection pool' do
      expect(Sidekiq.redis_pool).to be_a(described_class)
    end

    it 'connects to Redis' do
      expect(Sidekiq.redis { |connection| connection.call('PING') }).to eq('PONG')
    end

    it 'enqueues jobs through the pool' do
      Sidekiq::Client.push('class' => 'ApplicationJob', 'queue' => queue_name, 'args' => [])

      expect(Sidekiq::Queue.new(queue_name).size).to eq(1)
    end
  end
end
