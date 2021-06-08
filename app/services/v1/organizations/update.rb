# frozen_string_literal: true

class V1::Organizations::Update
  def self.call(organization, organization_params)
    new(organization, organization_params).call
  end

  def initialize(organization, organization_params)
    @organization = organization
    @organization_params = organization_params
  end

  def call
    ActiveRecord::Base.transaction do
      organization.update!(name: organization_params[:name]) if name_changed?

      V1::Organizations::ChangeOrganizationAdmins.call(
        organization,
        organization_params[:organization_admins_to_add],
        organization_params[:organization_admins_to_remove]
      )

      organization.reload
    end
  end

  private

  attr_reader :organization, :organization_params

  def new_organization_admin
    @new_organization_admin ||= User.limit_to_roles(%w[e_intervention_admin])
                                    .find(organization_params[:organization_admin_id])
  end

  def name_changed?
    return false if organization_params[:name].blank?

    organization.name != organization_params[:name]
  end
end
