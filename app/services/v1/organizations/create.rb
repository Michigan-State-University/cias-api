# frozen_string_literal: true

class V1::Organizations::Create
  def self.call(organization_params)
    new(organization_params).call
  end

  def initialize(organization_params)
    @organization_params = organization_params
  end

  def call
    ActiveRecord::Base.transaction do
      organization = Organization.create!(
        name: organization_params[:name]
      )

      add_new_organization_admin(organization) if new_organization_admin

      organization
    end
  end

  private

  attr_reader :organization_params

  def add_new_organization_admin(organization)
    organization.organization_admins << new_organization_admin
    new_organization_admin.organization = organization

    OrganizationInvitation.not_accepted.where(user_id: new_organization_admin.id).destroy_all
  end

  def new_organization_admin
    @new_organization_admin ||= User.limit_to_roles(%w[organization_admin])
                            .find_by(id: organization_params[:organization_admin_id])
  end
end
