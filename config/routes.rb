# frozen_string_literal: true

Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'
  root 'application#status'
  namespace :v1 do
    resources :interventions, only: %i[index show create] do
      resources :questions, only: %i[index show create update]
    end
    scope 'questions/:question_id' do
      resources :answers, only: %i[index show create]
    end
  end
end
