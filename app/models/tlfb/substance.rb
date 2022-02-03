# frozen_string_literal: true

class Tlfb::Substance < ApplicationRecord
  belongs_to :user_session

  attribute :body, :json, default: {}
  validates :body, json: {
    schema: -> { Rails.root.join("#{json_schema_path}/body.json").to_s },
    message: ->(err) { err }
  }

  private

  def json_schema_path
    'db/schema/tlfb/substance'
  end
end
