# frozen_string_literal: true

Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'
  root to: 'application#status'
  namespace :v1 do
    resources :interventions, only: %i[index show create] do
      resources :questions, only: %i[index create]
    end
  end
end
