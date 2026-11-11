# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SmsLinksUser, type: :model do
  subject { create(:sms_links_user) }

  it { should validate_uniqueness_of(:slug) }

  describe 'slug length cap' do
    let(:link) { create(:sms_link) }
    let(:users) { create_list(:user, 4) }

    before do
      link
      users
    end

    def stub_slug_source
      allow(SecureRandom).to receive(:base58).and_call_original
      allow(SecureRandom).to receive(:base58).with(5).and_return('aaaaa')
      allow(SecureRandom).to receive(:base58).with(2).and_return('bb')
    end

    def occupy(*slugs)
      slugs.each_with_index do |slug, i|
        described_class.create!(user: users[i], sms_link: link).update_column(:slug, slug)
      end
      stub_slug_source
    end

    it 'starts at base58(5)' do
      stub_slug_source
      expect(described_class.create!(user: users[0], sms_link: link).slug).to eq('aaaaa')
    end

    it 'extends twice at most and still succeeds with a 9-character slug' do
      occupy('aaaaa', 'aaaaabb')
      row = described_class.create!(user: users[2], sms_link: link)
      expect(row.slug).to eq('aaaaabbbb')
      expect(row.slug.length).to eq(9)
    end

    it 'raises once the two extension rounds are exhausted instead of recursing forever' do
      occupy('aaaaa', 'aaaaabb', 'aaaaabbbb')
      expect { described_class.create!(user: users[3], sms_link: link) }.to raise_error(StandardError)
    end

    it 'never persists a slug longer than 9 characters when the cap is hit' do
      occupy('aaaaa', 'aaaaabb', 'aaaaabbbb')
      begin
        described_class.create!(user: users[3], sms_link: link)
      rescue StandardError
        nil
      end
      expect(described_class.where('length(slug) > 9')).to be_empty
    end
  end
end
