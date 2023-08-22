# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:first_name) { |s| "first_name_#{s}" }
    sequence(:last_name) { |s| "last_name_#{s}" }
    sequence(:email) { |s| "email_#{s}@#{ENV['DOMAIN_NAME']}" }
    sequence(:password) { |s| "GcAbAijoW_#{s}" }
    provider { 'email' }
    terms { true }
    roles { %w[guest] }
    time_zone { 'Europe/Warsaw' }

    after(:create) do |user|
      user.user_verification_codes.create(code: "verification_code_#{user.uid}", confirmed: true)
    end

    transient do
      allow_unconfirmed_period { Time.current - Devise.allow_unconfirmed_access_for }
    end

    trait :confirmed do
      after(:create, &:confirm)
    end

    trait :admin do
      roles { %w[admin] }
    end

    trait :guest do
      roles { %w[guest] }
    end

    trait :participant do
      roles { %w[participant] }
    end

    trait :researcher do
      roles { %w[researcher] }
    end

    trait :third_party do
      roles { %w[third_party] }
    end

    trait :team_admin do
      roles { %w[researcher team_admin] }
      after(:build) do |team_admin|
        if team_admin.admins_teams.blank?
          new_team = build(:team, team_admin: team_admin)
          team_admin.admins_teams = [new_team]
        end
      end
    end

    trait :with_hfhs_patient_detail do
      after(:create) do |user|
        hfhs_detail_id = HfhsPatientDetail.create(patient_id: '89000344',
                                                  first_name: user.first_name,
                                                  last_name: user.last_name,
                                                  dob: (DateTime.now - 20.years).to_s,
                                                  sex: 'F',
                                                  visit_id: '',
                                                  phone_number: Faker::PhoneNumber.cell_phone,
                                                  phone_type: 'home',
                                                  zip_code: '48127').id
        user.update(hfhs_patient_detail_id: hfhs_detail_id)
      end
    end

    trait :organization_admin do
      roles { %w[organization_admin] }
    end

    trait :with_organization do
      after(:create, :build) do |organization_admin|
        if organization_admin.role?('organization_admin')
          new_organization = create(:organization)
          organization_admin.organizable = new_organization
          new_organization.organization_admins << organization_admin
        end
      end
    end

    trait :health_system_admin do
      roles { %w[health_system_admin] }
    end

    trait :with_health_system do
      after(:create, :build) do |health_system_admin|
        if health_system_admin.role?('health_system_admin')
          new_health_system = create(:health_system)
          health_system_admin.organizable = new_health_system
          new_health_system.health_system_admins << health_system_admin
        end
      end
    end

    trait :health_clinic_admin do
      roles { %w[health_clinic_admin] }
    end

    trait :with_health_clinic do
      after(:create, :build) do |health_clinic_admin|
        if health_clinic_admin.role?('health_clinic_admin')
          new_health_clinic = create(:health_clinic)
          health_clinic_admin.organizable = new_health_clinic unless health_clinic_admin.organizable
          health_clinic_admin.admins_health_clinics << new_health_clinic
          new_health_clinic.health_clinic_admins << health_clinic_admin
        end
      end
    end

    trait :e_intervention_admin do
      roles { %w[researcher e_intervention_admin] }
    end

    trait :preview_session do
      roles { %w[preview_session] }
      after(:build) do |user, evaluator|
        user.preview_session_id = evaluator.preview_session_id
      end
    end

    trait :unconfirmed do
      after(:create) do |user, evaluator|
        user.update_attribute(:confirmation_sent_at, evaluator.allow_unconfirmed_period - 1.day)
      end
    end

    trait :navigator do
      roles { %w[navigator] }
    end

    trait :researcher_and_navigator do
      roles { %w[researcher navigator] }
    end
  end
end
