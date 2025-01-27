# frozen_string_literal: true

RSpec.describe Link, type: :model do
  it { should validate_uniqueness_of(:slug) }
  it { should validate_presence_of(:url) }
  it { should allow_value('https://picsum.photos/200').for(:url) }

  describe 'callbacks' do
    it 'generate a slug before validation if blank' do
      link = build(:link, slug: nil)
      link.valid?
      expect(link.slug).not_to be_nil
    end
  end

  describe 'methods' do
    let!(:link) { create(:link) }
    let(:url) { link.url }
    let(:slug) { 'slug' }

    it '#short' do
      expect(link.short).to eq(Rails.application.routes.url_helpers.v1_short_url(slug: link.slug))
    end

    it '#shorten' do
      short_url = described_class.shorten(url)
      expect(short_url).not_to be_nil
      expect(described_class.find_by(url: url)).to eq(link)
    end

    it '#short with custom slug' do
      short_url = described_class.shorten(url, slug)
      expect(short_url).to eq(Rails.application.routes.url_helpers.v1_short_url(slug: slug))
    end

    context 'when slug is too long' do
      let(:slug) { SecureRandom.base58(256) }

      it '#short with custom slug' do
        expect { described_class.shorten(url, slug) }.to raise_error(ActiveRecord::ActiveRecordError)
      end
    end
  end
end
