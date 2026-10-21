# frozen_string_literal: true

RSpec.describe RedisAdapterOverrides do
  let(:redis_url) { ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  let(:server) do
    config = ActionCable::Server::Configuration.new
    config.cable = { adapter: 'redis', url: redis_url, channel_prefix: 'cias-api_test' }
    config.logger = Rails.logger
    ActionCable::Server::Base.new(config: config)
  end
  let(:adapter) { ActionCable::SubscriptionAdapter::Redis.new(server) }
  let(:redis_connection) { adapter.send(:redis_connection) }

  it 'is applied to the ActionCable Redis adapter' do
    expect(ActionCable::SubscriptionAdapter::Redis.ancestors).to include(described_class)
  end

  it 'builds the connection through the overridden connector' do
    connector = ActionCable::SubscriptionAdapter::Redis.redis_connector

    expect(connector.source_location.first).to end_with('app/channels/concerns/redis_adapter_overrides.rb')
  end

  it 'connects with the ruby driver and without ActionCable-only options' do
    expect(redis_connection).to be_a(Redis)
    expect(redis_connection._client.config.driver).to eq(RedisClient::RubyConnection)
    expect(redis_connection._client.config).to have_attributes(host: URI.parse(redis_url).host, port: URI.parse(redis_url).port)
  end

  it 'returns a working connection' do
    expect(redis_connection.ping).to eq('PONG')
  ensure
    redis_connection.close
  end
end
