# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261029100600_add_sms_eligible_to_phones')

RSpec.describe AddSmsEligibleToPhones do
  subject(:run_migration) { described_class.new.tap { |m| m.verbose = false }.up }

  let(:user) { create(:user, :confirmed, :participant) }

  # Simulate a pre-backfill row: valid phone whose flag was never computed (default false).
  def stranded(attrs)
    create(:phone, user: user, **attrs).tap { |p| p.update_column(:sms_eligible, false) } # rubocop:disable Rails/SkipsModelValidations
  end

  def eligible?(phone)
    Phone.find(phone.id).sms_eligible
  end

  it 'marks a qualifying phone eligible that the deploy left at false' do
    phone = stranded(PhoneNumberFixtures::US_MAIN)
    run_migration
    expect(eligible?(phone)).to be(true)
  end

  it 'leaves a non-eligible phone at false even when the flag was forced true' do
    phone = create(:phone, user: user, **PhoneNumberFixtures::PL_LANDLINE)
    phone.update_column(:sms_eligible, true) # rubocop:disable Rails/SkipsModelValidations
    run_migration
    expect(eligible?(phone)).to be(false)
  end

  it 'normalizes a legacy unnormalized number and marks it eligible' do
    phone = Phone.new(user: user, iso: 'US', prefix: '+1', number: '(201) 555-0123').tap do |p|
      p.save!(validate: false)
      p.update_column(:sms_eligible, false) # rubocop:disable Rails/SkipsModelValidations
    end
    run_migration
    expect(Phone.find(phone.id)).to have_attributes(number: '2015550123', sms_eligible: true)
  end

  it 'skips a phone with an unparsable number without raising, leaving it ineligible' do
    phone = Phone.new(user: user, iso: 'US', prefix: '+1', number: 'notanumber').tap do |p|
      p.save!(validate: false)
    end
    expect { run_migration }.not_to raise_error
    expect(eligible?(phone)).to be(false)
  end

  it 'writes no PaperTrail version while backfilling' do
    stranded(PhoneNumberFixtures::US_MAIN)
    expect { run_migration }.not_to change { PaperTrail::Version.where(item_type: 'Phone').count }
  end

  it 'writes no audit while backfilling' do
    stranded(PhoneNumberFixtures::US_MAIN)
    expect { run_migration }.not_to change { Audited::Audit.where(auditable_type: 'Phone').count }
  end
end
