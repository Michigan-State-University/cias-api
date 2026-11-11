# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PredefinedParticipants::SmsCampaigns::BodyLength do
  let(:web_host) { 'https://web.example.test' }
  let(:personal_link) { "\n#{web_host}/usr/".length + 8 }
  let(:tracked_link) { "#{web_host}/link/".length + 9 }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_host)) }

  def measure(body, variables = [])
    described_class.new(body, variables)
  end

  it 'counts the personal link appended to every message' do
    expect(measure('Hello').length).to eq(5 + personal_link)
  end

  it 'counts every occurrence of a link variable as an expanded tracked link' do
    expect(measure('::a:: and ::a::', ['a']).length).to eq(tracked_link + 5 + tracked_link + personal_link)
  end

  it 'does not expand a variable that has no link' do
    expect(measure('::a::').length).to eq(5 + personal_link)
  end

  it 'treats a body of GSM-7 characters as GSM-7 and one with other characters as UCS-2' do
    expect(measure('Zażółć').gsm7?).to be(false)
    expect(measure('Hello €[]').gsm7?).to be(true)
  end

  it 'counts a character outside the Basic Multilingual Plane as two UTF-16 units' do
    expect(measure('😀').length).to eq(2 + personal_link)
  end

  it 'counts GSM-7 segments of 160 and 153 septets with extension characters taking two septets' do
    expect(measure('a' * (160 - personal_link)).segments).to eq(1)
    expect(measure('a' * (161 - personal_link)).segments).to eq(2)
    expect(measure('a' * (306 - personal_link)).segments).to eq(2)
    expect(measure("#{'a' * (305 - personal_link)}€").segments).to eq(3)
  end

  it 'counts UCS-2 segments of 70 and 67 units' do
    expect(measure('ą' * (70 - personal_link)).segments).to eq(1)
    expect(measure('ą' * (134 - personal_link)).segments).to eq(2)
    expect(measure('ą' * (135 - personal_link)).segments).to eq(3)
  end

  describe '#codes' do
    let(:limit) { Settings.sms_campaigns.max_body_length }

    it 'accepts a body that reaches the length limit once expanded' do
      expect(measure("#{'a' * (limit - personal_link - tracked_link)}::a::", ['a']).codes).to be_empty
    end

    it 'rejects a body that exceeds the length limit by one character once expanded' do
      expect(measure("#{'a' * (limit - personal_link - tracked_link + 1)}::a::", ['a']).codes).to eq(['BODY_TOO_LONG'])
    end

    context 'when the segment limit is lower than the length limit allows' do
      around do |example|
        original = Settings.sms_campaigns.max_segments
        Settings.sms_campaigns.max_segments = 2
        example.run
      ensure
        Settings.sms_campaigns.max_segments = original
      end

      it 'accepts a body that fits in the allowed segments and rejects one segment more' do
        expect(measure('a' * (306 - personal_link)).codes).to be_empty
        expect(measure('a' * (307 - personal_link)).codes).to eq(['BODY_TOO_MANY_SEGMENTS'])
      end
    end
  end

  # Shared contract with the front end. `cias-web` asserts against this very
  # file (app/utils/tests/fixtures/smsBodyLengthContract.json), so when this
  # block turns red the counter in the browser has just drifted from the API.
  # Regenerate: bundle exec rake sms_campaigns:dump_body_length_contract
  describe 'shared counter contract with cias-web' do
    contract = JSON.parse(Rails.root.join('spec/fixtures/sms_campaigns/body_length_contract.json').read)

    before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => contract['webUrl'])) }

    it 'reproduces the parameters recorded in the fixture' do
      expect(described_class.personal_link_expected_length).to eq(contract['meta']['personalLinkExpectedLength'])
      expect(described_class.tracked_link_expected_length).to eq(contract['meta']['trackedLinkExpectedLength'])
      expect(Settings.sms_campaigns.max_body_length).to eq(contract['meta']['maxBodyLength'])
      expect(Settings.sms_campaigns.max_segments).to eq(contract['meta']['maxSegments'])
      expect(Settings.sms_campaigns.max_reminder_days_after).to eq(contract['meta']['maxReminderDaysAfter'])
    end

    contract['cases'].each_with_index do |row, index|
      it "reproduces case #{index}: #{row['note']}" do
        measure = described_class.new(row['body'], row['variables'])

        expect(measure.length).to eq(row['length'])
        expect(measure.segments).to eq(row['segments'])
        expect(measure.gsm7?).to be(row['gsm7'])
        expect(measure.codes).to eq(row['codes'])
      end
    end
  end
end
