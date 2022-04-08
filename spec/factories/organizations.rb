# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    sequence(:name) { |s| "organization_#{s}" }

    trait :with_organization_admin do
      after(:build) do |organization|
        organization_admin = create(:user, :confirmed, :organization_admin, organizable_id: organization.id)
        organization.organization_admins << organization_admin
        OrganizationInvitation.create!(user: organization_admin, organization: organization, accepted_at: Time.zone.now)
      end
    end

    trait :with_e_intervention_admin do
      after(:create) do |organization|
        organization.e_intervention_admins << create(:user, :confirmed, :e_intervention_admin, organizable: organization)
      end
    end

    trait :with_health_system do
      after(:build) do |organization|
        organization.health_systems << create(:health_system)
      end
    end

    trait :with_dashboard_section do
      after(:create) do |organization|
        organization.reporting_dashboard.dashboard_sections << create(:dashboard_section)
      end
    end
  end
end
