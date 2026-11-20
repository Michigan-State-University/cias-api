# frozen_string_literal: true

RSpec.describe TZInfo do
  describe 'data source' do
    it 'uses the bundled tzinfo-data, not the OS zoneinfo' do
      expect(described_class::DataSource.get).to be_a(described_class::DataSources::RubyDataSource)
    end
  end

  describe 'alias time zone names' do
    {
      'Asia/Saigon' => 'Asia/Ho_Chi_Minh',
      'Asia/Calcutta' => 'Asia/Kolkata',
      'Europe/Kiev' => 'Europe/Kyiv',
      'America/Indianapolis' => 'America/Indiana/Indianapolis',
      'US/Eastern' => 'America/New_York'
    }.each do |alias_name, canonical_name|
      it "resolves #{alias_name} to #{canonical_name}" do
        expect(described_class::Timezone.get(alias_name).canonical_identifier).to eq(canonical_name)
      end

      it "keeps #{alias_name} in User::TIME_ZONES" do
        expect(User::TIME_ZONES).to include(alias_name)
      end
    end
  end
end
