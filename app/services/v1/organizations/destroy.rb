# frozen_string_literal: true

class V1::Organizations::Destroy
  def self.call(organization)
    new(organization).call
  end

  def initialize(organization)
    @organization = organization
    @organization_admins = organization.organization_admins
  end

  def call
    ActiveRecord::Base.transaction do
      organization_admins.each do |organization_admin|
        organization_admin.deactivate!
      end

      organization.destroy!
    end
  end

  private

  attr_reader :organization, :organization_admins
end
