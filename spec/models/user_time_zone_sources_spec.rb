# frozen_string_literal: true

RSpec.describe User do
  client_time_zones = JSON.parse(Rails.root.join('spec/fixtures/time_zones/client_time_zones.json').read)
  phonelib_time_zones = Phonelib.phone_ext_data[Phonelib::Core::EXT_TIMEZONES]
                                .flatten.flat_map { |zones| zones.to_s.split('&') }.compact_blank.uniq

  describe 'time zones that clients send' do
    {
      'browsers (Intl API, as Chrome reports them)' => client_time_zones.fetch('browser_intl'),
      'the cias-web time zone dropdown' => client_time_zones.fetch('cias_web_dropdown'),
      'Phonelib (derived from a phone number)' => phonelib_time_zones
    }.each do |source, time_zones|
      it "accepts every zone from #{source} (#{time_zones.size} zones)" do
        expect(time_zones - described_class::TIME_ZONES).to be_empty
      end
    end
  end

  describe 'accepted time zones' do
    it 'can all be used by ActiveSupport' do
      unusable = described_class::TIME_ZONES.reject { |time_zone| ActiveSupport::TimeZone[time_zone] }
      expect(unusable).to be_empty
    end
  end
end
