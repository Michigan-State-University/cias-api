# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PredefinedUserParameter, type: :model do
  subject { create(:predefined_user_parameter) }

  let(:intervention) { create(:intervention, :published) }

  it { should belong_to(:user) }
  it { should belong_to(:intervention) }
  it { should belong_to(:health_clinic).optional(true) }
  it { should validate_uniqueness_of(:slug) }

  it 'rejects a duplicate slug at the database level' do
    expect { create(:predefined_user_parameter).update_column(:slug, subject.slug) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it '#generate_slug' do
    expect(described_class.create!(user: create(:user), intervention: create(:intervention)).slug).to be_present
  end

  describe 'sms_deliveries association' do
    it 'has many sms_deliveries destroyed with the participant' do
      expect(described_class.new).to have_many(:sms_deliveries)
        .class_name('PredefinedParticipants::SmsDelivery').dependent(:destroy)
    end

    it 'destroys the deliveries (and their stored bodies) with the participant' do
      participant = create(:predefined_user_parameter, intervention: intervention)
      delivery = create(:pdp_sms_delivery, predefined_user_parameter: participant,
                                           campaign: create(:pdp_sms_campaign, intervention: intervention))
      participant.destroy!
      expect(PredefinedParticipants::SmsDelivery.exists?(delivery.id)).to be(false)
    end
  end

  describe 'slug length cap' do
    let(:user) { create(:user) }

    before do
      user
      intervention
    end

    def stub_slug_source
      allow(SecureRandom).to receive(:base58).and_call_original
      allow(SecureRandom).to receive(:base58).with(4).and_return('aaaa')
      allow(SecureRandom).to receive(:base58).with(2).and_return('bb')
    end

    def occupy(*slugs)
      slugs.each do |slug|
        create(:predefined_user_parameter, intervention: intervention).update_column(:slug, slug)
      end
      stub_slug_source
    end

    it 'starts at base58(4)' do
      stub_slug_source
      participant = described_class.create!(user: user, intervention: intervention)
      expect(participant.slug).to eq('aaaa')
    end

    it 'extends twice at most and still succeeds with an 8-character slug' do
      occupy('aaaa', 'aaaabb')
      participant = described_class.create!(user: user, intervention: intervention)
      expect(participant.slug).to eq('aaaabbbb')
      expect(participant.slug.length).to eq(8)
    end

    it 'raises once the two extension rounds are exhausted instead of recursing forever' do
      occupy('aaaa', 'aaaabb', 'aaaabbbb')
      expect { described_class.create!(user: user, intervention: intervention) }.to raise_error(StandardError)
    end

    it 'never persists a slug longer than 8 characters when the cap is hit' do
      occupy('aaaa', 'aaaabb', 'aaaabbbb')
      begin
        described_class.create!(user: user, intervention: intervention)
      rescue StandardError
        nil
      end
      expect(described_class.where('length(slug) > 8')).to be_empty
    end
  end
end
