# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::PredefinedParticipants::SmsCampaigns::CampaignAttributes do
  subject(:attributes) { described_class.new(params) }

  def action_controller_params(hash)
    ActionController::Parameters.new(hash).permit!
  end

  describe '#kind' do
    it 'coerces the kind to a string' do
      expect(described_class.new(kind: :invitation).kind).to eq('invitation')
    end

    it 'returns an empty string when the kind is missing' do
      expect(described_class.new({}).kind).to eq('')
    end
  end

  describe '#body' do
    it 'normalises the body to Unicode NFC' do
      decomposed = "Cafe\u0301"
      expect(decomposed).not_to eq(decomposed.unicode_normalize(:nfc))
      expect(described_class.new(body: decomposed).body).to eq(decomposed.unicode_normalize(:nfc))
    end

    it 'coerces a non-string body to a string before normalising' do
      expect(described_class.new(body: nil).body).to eq('')
    end

    it 'returns an empty string for an invalidly encoded body' do
      invalid = "abc\xFFdef".dup.force_encoding('UTF-8')
      expect(invalid.valid_encoding?).to be(false)
      expect(described_class.new(body: invalid).body).to eq('')
    end

    it 'memoises the normalised body' do
      params = { body: 'hello' }
      object = described_class.new(params)
      expect(object.body).to equal(object.body)
    end
  end

  describe '#links' do
    let(:params) do
      { links: [{ url: 'https://example.test', variable: 'link_one', link_type: 'website', extra: 'drop-me' }] }
    end

    it 'maps each link to the whitelisted attributes only' do
      expect(attributes.links).to eq([{ 'url' => 'https://example.test', 'variable' => 'link_one', 'link_type' => 'website' }])
    end

    it 'returns an empty array when links are missing' do
      expect(described_class.new({}).links).to eq([])
    end

    it 'drops blank values from a link' do
      object = described_class.new(links: [{ url: 'https://example.test', variable: '', link_type: 'website' }])
      expect(object.links).to eq([{ 'url' => 'https://example.test', 'link_type' => 'website' }])
    end

    it 'memoises the mapped links' do
      expect(attributes.links).to equal(attributes.links)
    end
  end

  describe '#link_attributes via #links' do
    let(:link_hash) { { url: 'https://example.test', variable: 'link_one', link_type: 'website', extra: 'drop-me' } }
    let(:expected) { [{ 'url' => 'https://example.test', 'variable' => 'link_one', 'link_type' => 'website' }] }

    it 'handles a plain Ruby Hash link' do
      expect(described_class.new(links: [link_hash]).links).to eq(expected)
    end

    it 'handles an ActionController::Parameters link via to_unsafe_h' do
      params = action_controller_params(links: [link_hash])
      expect(described_class.new(params).links).to eq(expected)
    end
  end

  describe '#reminder and #reminder?' do
    it 'returns the raw scheduled_reminder payload' do
      reminder = { body: 'Remind', days_after: 3 }
      expect(described_class.new(scheduled_reminder: reminder).reminder).to eq(reminder)
    end

    it 'is reminder? true when present and false when absent' do
      expect(described_class.new(scheduled_reminder: { body: 'x' }).reminder?).to be(true)
      expect(described_class.new({}).reminder?).to be(false)
    end
  end

  describe '#reminder_body' do
    it 'normalises the reminder body to Unicode NFC' do
      decomposed = "Cafe\u0301"
      object = described_class.new(scheduled_reminder: { body: decomposed })
      expect(object.reminder_body).to eq(decomposed.unicode_normalize(:nfc))
    end
  end

  describe '#reminder_links' do
    it 'maps the reminder links to the whitelisted attributes' do
      object = described_class.new(
        scheduled_reminder: { links: [{ url: 'https://example.test', variable: 'r', link_type: 'website' }] }
      )
      expect(object.reminder_links).to eq([{ 'url' => 'https://example.test', 'variable' => 'r', 'link_type' => 'website' }])
    end
  end

  describe '#days_after' do
    it 'returns the integer when the value is an integer' do
      expect(described_class.new(scheduled_reminder: { days_after: 3 }).days_after).to eq(3)
    end

    it 'coerces a numeric string to an integer' do
      expect(described_class.new(scheduled_reminder: { days_after: '5' }).days_after).to eq(5)
    end

    it 'returns nil for a non-integer value' do
      expect(described_class.new(scheduled_reminder: { days_after: 'abc' }).days_after).to be_nil
    end

    it 'returns nil when days_after is missing' do
      expect(described_class.new(scheduled_reminder: {}).days_after).to be_nil
    end
  end
end
