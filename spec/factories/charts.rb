FactoryBot.define do
  factory :chart do
    sequence(:name) { |n| "#{Faker::Alphanumeric.alpha(number: 6)} #{n}" }
    association(:organization)
  end
end
