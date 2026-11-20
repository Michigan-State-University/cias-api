# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261029100300_add_reminder_columns_to_predefined_user_parameters')

RSpec.describe AddReminderColumnsToPredefinedUserParameters do
  subject(:run_migration) { described_class.new.tap { |m| m.verbose = false }.up }

  let(:intervention) { create(:intervention, :published) }
  let(:user) { create(:user, :confirmed, :participant) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention) }

  def pup_with(first_opened_at: nil)
    PredefinedUserParameter.create!(user: user, intervention: intervention, first_opened_at: first_opened_at)
  end

  def session_opened_at(factory, created_at, session: self.session)
    create(factory, user: user, session: session, user_intervention: user_intervention).tap do |us|
      us.update_column(:created_at, created_at)
    end
  end

  it 'backfills first_opened_at from the earliest non-RA session' do
    pup = pup_with
    session_opened_at(:user_session, 5.days.ago, session: create(:session, intervention: intervention))
    session_opened_at(:user_session, 2.days.ago, session: create(:session, intervention: intervention))
    run_migration
    expect(pup.reload.first_opened_at).to be_within(1.second).of(5.days.ago)
  end

  it 'leaves first_opened_at nil for a participant with only RA sessions' do
    pup = pup_with
    session_opened_at(:ra_user_session, 3.days.ago)
    run_migration
    expect(pup.reload.first_opened_at).to be_nil
  end

  it 'does not overwrite an existing first_opened_at' do
    existing = 10.days.ago
    pup = pup_with(first_opened_at: existing)
    session_opened_at(:user_session, 2.days.ago)
    run_migration
    expect(pup.reload.first_opened_at).to be_within(1.second).of(existing)
  end
end
