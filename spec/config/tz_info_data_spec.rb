# frozen_string_literal: true

RSpec.describe TZInfo do
  it 'uses the bundled tzinfo-data, not the OS zoneinfo' do
    expect(described_class::DataSource.get).to be_a(described_class::DataSources::RubyDataSource)
  end
end
