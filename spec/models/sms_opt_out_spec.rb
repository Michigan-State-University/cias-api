# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SmsOptOut', type: :model do
  let(:model) { 'SmsOptOut'.constantize }
  let(:user) { create(:user) }

  include SchemaAssertionHelpers

  describe 'opt-out keyed on the user' do
    it 'stores one opt-out for a user' do
      record = model.create!(user_id: user.id, opted_out_at: Time.zone.parse('2026-10-29 12:00:00'))
      expect(record.reload.user_id).to eq(user.id)
      expect(record.opted_out_at).to eq(Time.zone.parse('2026-10-29 12:00:00'))
    end

    it 'rejects a second opt-out for the same user at the database level' do
      model.create!(user_id: user.id, opted_out_at: Time.zone.parse('2026-10-29 12:00:00'))
      expect_unique_violation do
        model.new(user_id: user.id, opted_out_at: Time.zone.parse('2026-10-29 13:00:00')).save!(validate: false)
      end
    end

    it 'refuses an opt-out for a missing user at the database level' do
      expect_fk = expect do
        ActiveRecord::Base.transaction(requires_new: true) do
          model.new(user_id: SecureRandom.uuid, opted_out_at: Time.current).save!(validate: false)
        end
      end
      expect_fk.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'builds through the factory with a user' do
      expect(create(:pdp_sms_opt_out, user: user).user_id).to eq(user.id)
    end
  end
end
