# frozen_string_literal: true

class V1::Organizations::Destroy
  def self.call(organization)
    new(organization).call
  end

  def initialize(organization)
    @organization = organization
  end

  def call
    ActiveRecord::Base.transaction do
      organization.destroy!
    end
  end

  private

  attr_reader :organization
end
