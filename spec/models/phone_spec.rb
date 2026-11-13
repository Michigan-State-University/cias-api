# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Phone, type: :model do
  describe 'confirmation on update' do
    let(:confirmed_at) { Time.zone.parse('2026-10-01 12:00:00') }
    let(:stored_number) { '(202) 555-0143' }
    let(:phone) do
      described_class.new(user: create(:user, :confirmed, :participant), iso: 'US', prefix: '+1', number: stored_number,
                          confirmed: true, confirmed_at: confirmed_at, confirmation_code: '1234').tap { |p| p.save!(validate: false) }
    end

    def reloaded
      described_class.find(phone.id)
    end

    context 'with a legacy number stored unnormalized' do
      it 'keeps the confirmation when an unrelated update normalizes the number' do
        reloaded.update!(communication_way: 'message')
        expect(reloaded).to have_attributes(number: '2025550143', confirmed: true, confirmed_at: confirmed_at)
      end

      it 'keeps the new confirmation code when the code is refreshed' do
        reloaded.refresh_confirmation_code
        expect(reloaded.confirmation_code).to be_present
      end

      it 'drops the confirmation when the number changes' do
        reloaded.update!(number: '2025550199')
        expect(reloaded).to have_attributes(confirmed: false, confirmed_at: nil, confirmation_code: nil)
      end
    end

    context 'with a normalized number' do
      let(:stored_number) { '2025550143' }

      it 'keeps the confirmation when the same number arrives formatted' do
        reloaded.update!(number: '202-555-0143')
        expect(reloaded).to have_attributes(confirmed: true, confirmed_at: confirmed_at)
      end
    end

    context 'with a number valid under two country codes' do
      let(:phone) do
        create(:phone, iso: 'PL', prefix: '+48', number: '512345678').tap do |p|
          p.update_columns(confirmed: true, confirmed_at: confirmed_at)
        end
      end

      it 'drops the confirmation when only the prefix changes' do
        reloaded.update!(iso: 'ES', prefix: '+34')
        expect(reloaded).to have_attributes(confirmed: false, confirmed_at: nil)
      end
    end

    context 'with a legacy number that cannot be parsed' do
      let(:stored_number) { 'notanumber' }

      it 'drops the confirmation when the number changes' do
        reloaded.update!(number: '2025550143')
        expect(reloaded.confirmed).to be(false)
      end
    end

    context 'with a legacy prefix that cannot be parsed' do
      let(:phone) do
        described_class.new(user: create(:user, :confirmed, :participant), iso: 'US', prefix: '+999', number: '2025550143',
                            confirmed: true, confirmed_at: confirmed_at, confirmation_code: '1234').tap { |p| p.save!(validate: false) }
      end

      it 'drops the confirmation when only the prefix changes' do
        reloaded.update!(prefix: '+1')
        expect(reloaded).to have_attributes(confirmed: false, confirmed_at: nil, confirmation_code: nil)
      end
    end
  end

  describe 'national number storage' do
    {
      'GB' => ['+44', '7400123456'], 'DE' => ['+49', '15112345678'], 'FR' => ['+33', '612345678'],
      'AU' => ['+61', '412345678'], 'AR' => ['+54', '91123456789'], 'RU' => ['+7', '9123456789'],
      'US' => ['+1', '2025550143'], 'PL' => ['+48', '512345678']
    }.each do |iso, (prefix, national)|
      it "stores a #{iso} number without the trunk prefix so full_number is E.164" do
        phone = create(:phone, iso: iso, prefix: prefix, number: national)
        expect(described_class.find(phone.id).full_number).to eq(Phonelib.parse("#{prefix}#{national}").e164)
      end
    end

    it 'drops a trunk prefix typed by the user' do
      phone = create(:phone, iso: 'GB', prefix: '+44', number: '07400 123456')
      expect(described_class.find(phone.id).number).to eq('7400123456')
    end

    describe 'NANP territories sharing country code +1' do
      PhoneNumberFixtures::NANP_SHARED_COUNTRY_CODE.each do |label, attrs|
        it "stores #{label} as prefix +1 so full_number is E.164" do
          phone = create(:phone, **attrs)
          expect(described_class.find(phone.id).full_number).to eq(Phonelib.parse("+1#{attrs[:number]}").e164)
        end

        it "keeps #{label} writable once stored" do
          phone = create(:phone, **attrs)
          expect(phone.update(communication_way: 'message')).to be(true)
        end
      end
    end
  end

  describe 'number validation and normalisation' do
    let(:user) { create(:user, :confirmed, :participant) }

    def phone_with(iso:, prefix:, number:, **extra)
      described_class.new(iso: iso, prefix: prefix, number: number, user: user, **extra)
    end

    def build_phone(attrs)
      described_class.new(attrs)
    end

    describe 'syntactically invalid numbers are rejected' do
      {
        'a number Phonelib rejects (+48111222331)' => { iso: 'PL', prefix: '+48', number: '111222331' },
        'a non-numeric string' => { iso: 'PL', prefix: '+48', number: 'notanumber' },
        'a short code (55555)' => { iso: 'US', prefix: '+1', number: '55555' },
        'a short code (116)' => { iso: 'US', prefix: '+1', number: '116' }
      }.each do |label, attrs|
        context "with #{label}" do
          subject(:phone) { phone_with(**attrs) }

          it 'is invalid' do
            expect(phone).not_to be_valid
          end

          it 'reports the problem on number' do
            phone.valid?
            expect(phone.errors.attribute_names).to include(:number)
          end

          it 'refuses to persist' do
            expect { phone.save }.to avoid_changing(described_class, :count)
          end

          it 'raises RecordInvalid from create!' do
            expect { phone.save! }.to raise_error(ActiveRecord::RecordInvalid)
          end
        end
      end

      context 'when an existing valid phone is updated to an invalid number' do
        let!(:phone) { create(:phone, user: user, iso: 'US', prefix: '+1', number: '2015550123') }

        it 'rejects the update' do
          expect(phone.update(iso: 'PL', prefix: '+48', number: '111222331')).to be(false)
        end

        it 'leaves the stored number untouched' do
          phone.update(iso: 'PL', prefix: '+48', number: '111222331')
          expect(described_class.find(phone.id)).to have_attributes(iso: 'US', prefix: '+1', number: '2015550123')
        end
      end
    end

    describe 'valid numbers that are not SMS recipients are still valid contact numbers' do
      {
        'a GB mobile' => { iso: 'GB', prefix: '+44', number: '7400123456' },
        'a FR mobile' => { iso: 'FR', prefix: '+33', number: '612345678' },
        'a US premium-rate number' => { iso: 'US', prefix: '+1', number: '9002221234' },
        'a PL premium-rate number' => { iso: 'PL', prefix: '+48', number: '701123456' },
        'a PL landline' => { iso: 'PL', prefix: '+48', number: '123456789' }
      }.each do |label, attrs|
        it "persists #{label}" do
          expect { phone_with(**attrs).save! }.to change(described_class, :count).by(1)
        end
      end
    end

    describe 'the blank-number exemption for alert phones survives' do
      let(:session) { create(:session, intervention: create(:intervention, user: user)) }
      let(:sms_alert) { create(:sms_plan, type: 'SmsPlan::Alert', session: session) }

      it 'creates a placeholder phone with a blank number' do
        expect { described_class.create!(iso: 'US', prefix: '+1', number: '') }.to change(described_class, :count).by(1)
      end

      it 'leaves iso and prefix of a blank placeholder as submitted' do
        phone = described_class.create!(iso: 'US', prefix: '+1', number: '')
        expect(phone.reload).to have_attributes(iso: 'US', prefix: '+1')
      end

      context 'when the phone belongs to an alert' do
        let!(:phone) { create(:phone, :confirmed, iso: 'US', prefix: '+1', number: '2015550123') }

        before { sms_alert.phones << phone }

        it 'allows clearing the number' do
          expect(phone.update(number: '')).to be(true)
        end

        it 'stores the blank number' do
          phone.update!(number: '')
          expect(described_class.find(phone.id).number).to be_blank
        end
      end

      it 'still requires a number to remain present on a regular phone update' do
        phone = create(:phone, **PhoneNumberFixtures::US_MAIN)
        expect(phone.update(number: '')).to be(false)
      end
    end

    describe 'normalization to the Phonelib split' do
      ['(201) 555-0123', '201-555-0123', '201 555 0123', '201.555.0123', '2015550123'].each do |raw|
        it "stores US input #{raw.inspect} as prefix +1, number 2015550123, iso US" do
          phone = phone_with(iso: 'US', prefix: '+1', number: raw)
          phone.save!
          expect(phone.reload).to have_attributes(iso: 'US', prefix: '+1', number: '2015550123')
        end
      end

      ['512 345 678', '512-345-678', '512345678'].each do |raw|
        it "stores PL input #{raw.inspect} as prefix +48, number 512345678, iso PL" do
          phone = phone_with(iso: 'PL', prefix: '+48', number: raw)
          phone.save!
          expect(phone.reload).to have_attributes(iso: 'PL', prefix: '+48', number: '512345678')
        end
      end

      it 'takes iso from the parsed country rather than the submitted value' do
        phone = phone_with(iso: 'PL', prefix: '+1', number: '2015550123')
        phone.save!
        expect(phone.reload.iso).to eq('US')
      end

      it 'upcases a lowercase iso through the parsed country' do
        phone = phone_with(iso: 'us', prefix: '+1', number: '2015550123')
        phone.save!
        expect(phone.reload.iso).to eq('US')
      end

      it 'normalizes on update as well' do
        phone = create(:phone, user: user, iso: 'US', prefix: '+1', number: '2015550124')
        phone.update!(number: '(201) 555-0125')
        expect(phone.reload).to have_attributes(prefix: '+1', number: '2015550125', iso: 'US')
      end

      it 'makes the normalized record findable through the blind index' do
        phone_with(iso: 'US', prefix: '+1', number: '(201) 555-0123').save!
        expect(described_class.find_by(number: '2015550123')).to be_present
      end
    end

    describe 're-saving a confirmed phone in another format keeps the confirmation' do
      let(:confirmed_at) { Time.zone.parse('2026-10-29 12:00:00') }
      let!(:phone) do
        create(:phone, :confirmed, user: user, iso: 'US', prefix: '+1', number: '2015550123').tap do |p|
          p.update_columns(confirmed: true, confirmed_at: confirmed_at)
        end
      end

      ['(201) 555-0123', '201-555-0123', '201 555 0123'].each do |raw|
        it "keeps confirmed when the same number arrives as #{raw.inspect}" do
          phone.update!(number: raw)
          expect(phone.reload.confirmed).to be(true)
        end
      end

      it 'keeps confirmed_at when the same number arrives in another format' do
        phone.update!(iso: 'US', prefix: '+1', number: '(201) 555-0123')
        expect(phone.reload.confirmed_at).to eq(confirmed_at)
      end

      it 'still drops the confirmation for a genuinely different number' do
        phone.update!(number: '2015550124')
        expect(phone.reload).to have_attributes(confirmed: false, confirmed_at: nil)
      end

      it 'still drops the confirmation for a different number written in another format' do
        phone.update!(number: '(201) 555-0124')
        expect(phone.reload.confirmed).to be(false)
      end
    end

    describe 'valid contact numbers are never rejected by validation' do
      PhoneNumberFixtures::VALID_BUT_NOT_ELIGIBLE.each do |label, attrs|
        context "with #{label}" do
          it 'is valid' do
            expect(build_phone(attrs)).to be_valid
          end

          it 'is persisted' do
            expect { described_class.create!(attrs) }.to change(described_class, :count).by(1)
          end
        end
      end
    end
  end

  describe 'sms_eligible classification' do
    let(:user) { create(:user, :confirmed, :participant) }

    let(:us_mobile) { { iso: 'US', prefix: '+1', number: '2015550123' } }
    let(:us_other) { { iso: 'US', prefix: '+1', number: '2015550124' } }
    let(:pl_mobile) { { iso: 'PL', prefix: '+48', number: '512345678' } }
    let(:gb_mobile) { { iso: 'GB', prefix: '+44', number: '7400123456' } }
    let(:fr_mobile) { { iso: 'FR', prefix: '+33', number: '612345678' } }
    let(:us_premium) { { iso: 'US', prefix: '+1', number: '9002221234' } }
    let(:pl_premium) { { iso: 'PL', prefix: '+48', number: '701123456' } }
    let(:pl_landline) { { iso: 'PL', prefix: '+48', number: '123456789' } }

    def eligible?(phone)
      described_class.find(phone.id).sms_eligible
    end

    describe 'qualifying numbers' do
      it 'is true for a valid US number' do
        expect(eligible?(create(:phone, user: user, **us_mobile))).to be(true)
      end

      it 'is true for a valid PL mobile' do
        expect(eligible?(create(:phone, user: user, **pl_mobile))).to be(true)
      end

      it 'treats a fixed_or_mobile US number as a mobile-capable type' do
        expect(Phonelib.parse('+12015550123').types).to eq([:fixed_or_mobile])
        expect(eligible?(create(:phone, user: user, **us_mobile))).to be(true)
      end

      it 'stays true when updated to another valid number' do
        phone = create(:phone, user: user, **us_mobile)
        phone.update!(**us_other)
        expect(eligible?(phone)).to be(true)
      end

      it 'is true when the number arrives in a non-canonical format' do
        phone = create(:phone, user: user, iso: 'US', prefix: '+1', number: '(201) 555-0123')
        expect(eligible?(phone)).to be(true)
      end
    end

    describe 'the destination country is not a criterion' do
      PhoneNumberFixtures::ELIGIBLE_INTERNATIONAL.each do |label, attrs|
        it "is true for #{label}" do
          expect(eligible?(create(:phone, user: user, **attrs))).to be(true)
        end
      end

      it 'stays true when a US phone is updated to a GB number' do
        phone = create(:phone, user: user, **us_mobile)
        expect(phone.update(**gb_mobile)).to be(true)
        expect(eligible?(phone)).to be(true)
      end

      it 'still records the GB iso and +44 prefix' do
        phone = create(:phone, user: user, **gb_mobile)
        expect(phone.reload).to have_attributes(iso: 'GB', prefix: '+44')
      end
    end

    describe 'premium-rate is a criterion, not a validation' do
      it 'is false for a US premium-rate number and the save succeeds' do
        phone = described_class.new(user: user, **us_premium, sms_eligible: true)
        expect(phone.save).to be(true)
        expect(eligible?(phone)).to be(false)
      end

      it 'is false for a PL premium-rate number' do
        phone = described_class.new(user: user, **pl_premium, sms_eligible: true)
        expect(phone.save).to be(true)
        expect(eligible?(phone)).to be(false)
      end

      it 'flips to false when an eligible phone is updated to premium-rate, and the update succeeds' do
        phone = create(:phone, user: user, **us_mobile)
        expect(eligible?(phone)).to be(true)
        expect(phone.update(**us_premium)).to be(true)
        expect(eligible?(phone)).to be(false)
      end
    end

    describe 'landline is a criterion, not a validation' do
      it 'is false for a PL landline and the save succeeds' do
        expect(Phonelib.parse('+48123456789').types).to eq([:fixed_line])
        phone = described_class.new(user: user, **pl_landline, sms_eligible: true)
        expect(phone.save).to be(true)
        expect(eligible?(phone)).to be(false)
      end

      it 'flips to false when an eligible phone is updated to a landline, and the update succeeds' do
        phone = create(:phone, user: user, **pl_mobile)
        expect(eligible?(phone)).to be(true)
        expect(phone.update(**pl_landline)).to be(true)
        expect(eligible?(phone)).to be(false)
      end
    end

    describe 'blank number' do
      let(:session) { create(:session, intervention: create(:intervention, user: user)) }
      let(:sms_alert) { create(:sms_plan, type: 'SmsPlan::Alert', session: session) }

      it 'is false for a blank placeholder phone and the save succeeds' do
        phone = described_class.new(iso: 'US', prefix: '+1', number: '', sms_eligible: true)
        expect(phone.save).to be(true)
        expect(eligible?(phone)).to be(false)
      end

      it 'drops to false when an alert phone is cleared, and the update succeeds' do
        phone = create(:phone, :confirmed, **us_mobile)
        sms_alert.phones << phone
        expect(eligible?(phone)).to be(true)
        expect(phone.update(number: '')).to be(true)
        expect(eligible?(phone)).to be(false)
      end
    end

    describe 'the flag is recomputed on every save' do
      it 'corrects a flag forced to false on a GB number at the next ordinary save' do
        phone = create(:phone, user: user, **gb_mobile)
        phone.update_column(:sms_eligible, false)
        described_class.find(phone.id).save!
        expect(eligible?(phone)).to be(true)
      end

      it 'corrects a flag forced to true on a premium-rate number when an unrelated field changes' do
        phone = create(:phone, user: user, **us_premium)
        phone.update_column(:sms_eligible, true)
        described_class.find(phone.id).update!(communication_way: 'call')
        expect(eligible?(phone)).to be(false)
      end

      it 'corrects a flag forced to true on a landline at the next ordinary save' do
        phone = create(:phone, user: user, **pl_landline)
        phone.update_column(:sms_eligible, true)
        described_class.find(phone.id).save!
        expect(eligible?(phone)).to be(false)
      end

      it 'corrects a flag forced to false on a qualifying number at the next ordinary save' do
        phone = create(:phone, user: user, **us_mobile)
        phone.update_column(:sms_eligible, false)
        described_class.find(phone.id).save!
        expect(eligible?(phone)).to be(true)
      end

      it 'does not touch the stored number when only recomputing' do
        phone = create(:phone, user: user, **us_mobile)
        phone.update_column(:sms_eligible, false)
        described_class.find(phone.id).save!
        expect(described_class.find(phone.id)).to have_attributes(prefix: '+1', number: '2015550123', iso: 'US')
      end
    end

    describe 'ineligible numbers save but are not eligible' do
      PhoneNumberFixtures::VALID_BUT_NOT_ELIGIBLE.each do |label, attrs|
        context "with #{label}" do
          it 'saves and ends up false even when the flag is passed as true on create' do
            phone = described_class.create!(attrs.merge(sms_eligible: true))
            expect(eligible?(phone)).to be(false)
          end

          it 'ends up false when an eligible phone is updated to it' do
            phone = described_class.create!(PhoneNumberFixtures::US_MAIN)
            expect(eligible?(phone)).to be(true)
            expect(phone.update(attrs)).to be(true)
            expect(eligible?(phone)).to be(false)
          end
        end
      end
    end

    describe 'recomputing eligibility leaves the confirmation untouched' do
      it 'does not change confirmation state when only eligibility is recomputed' do
        phone = create(:phone, **PhoneNumberFixtures::US_MAIN, confirmed: true, confirmed_at: Time.zone.parse('2026-01-02 03:04:05'))
        phone.update_column(:sms_eligible, false)
        described_class.find(phone.id).update!(communication_way: 'call')
        expect(eligible?(phone)).to be(true)
        expect(described_class.find(phone.id)).to be_confirmed
      end
    end
  end

  describe '.factory' do
    it 'builds a phone that passes the model validation' do
      expect(build_list(:phone, 5)).to all(be_valid)
    end

    it 'produces numbers Phonelib accepts as a US mobile-capable number' do
      phones = build_list(:phone, 5)
      expect(phones.map { |p| Phonelib.parse(p.full_number) }).to all(have_attributes(valid?: true, country: 'US'))
    end

    it 'does not repeat a number within one batch' do
      expect(build_list(:phone, 10).map(&:number).uniq.size).to eq(10)
    end

    it 'persists the default phone as sms-eligible' do
      expect(create(:phone).reload.sms_eligible).to be(true)
    end

    it 'keeps the confirmed trait working' do
      expect(create(:phone, :confirmed).reload.confirmed).to be(true)
    end
  end
end
