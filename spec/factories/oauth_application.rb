# frozen_string_literal: true

FactoryBot.define do
  factory :oauth_application, class: 'Doorkeeper::Application' do
    name { 'test' }
    uid { 'test' }
    secret { 'test' }
    redirect_uri { '' }
  end
end
