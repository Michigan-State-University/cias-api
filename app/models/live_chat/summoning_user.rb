# frozen_string_literal: true

class LiveChat::SummoningUser < ApplicationRecord
  self.table_name = 'live_chat_summoning_users'

  belongs_to :user
  belongs_to :intervention

  def call_out_available?
    return true if unlock_next_call_out_time.nil?

    (unlock_next_call_out_time - Time.zone.now).negative?
  end
end
