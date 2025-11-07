# frozen_string_literal: true

class SmsCampaignEvent < ApplicationRecord
  belongs_to :user_session, optional: true
end
