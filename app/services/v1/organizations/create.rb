# frozen_string_literal: true

class V1::Organizations::Create
  prepend Database::Transactional

  def self.call(organization_params)
    new(organization_params).call
  end

  def initialize(organization_params)
    @organization_params = organization_params
  end

  def call
    organization = Organization.create!(
      name: organization_params[:name]
    )

    V1::Organizations::ChangeOrganizationAdmins.call(
      organization,
      organization_params[:organization_admins_to_add],
      nil
    )

    organization
  end

  private

  attr_reader :organization_params
end
