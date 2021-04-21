# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    sequence(:name) { |s| "organization_#{s}" }

    trait :with_organization_admin do
      after(:create, :build) do |organization|
        organization_admin = create(:user, :confirmed, :organization_admin)
        organization.organization_admins << organization_admin
        organization_admin.organization = organization
      end
    end

    trait :with_e_intervention_admin do
      after(:create, :build) do |organization|
        organization.e_intervention_admins << create(:user, :confirmed, :e_intervention_admin, organization_id: organization.id)
      end
    end

    trait :with_health_systems do
      after(:create) do |organization|
        organization.health_systems << create(:health_system, :with_clinics)
      end
    end
  end
end
