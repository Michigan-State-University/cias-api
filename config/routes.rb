# frozen_string_literal: true

require 'sidekiq/web' if Rails.env.development?

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: '/rails/browse_emails' if Rails.env.development?
  mount_devise_token_auth_for 'User', at: 'auth'
  root 'application#status'
  namespace :v1 do
    resources :users, only: %i[index show update destroy]
    resources :interventions, only: %i[index show create update] do
      patch 'questions/position', to: 'questions#position'
      resources :questions, only: %i[index show create update destroy] do
        member do
          get 'clone'
        end
      end
    end
    scope 'questions/:question_id' do
      resources :answers, only: %i[index show create]
      scope module: 'questions' do
        resource :images, only: %i[create destroy]
      end
    end
  end
  mount Sidekiq::Web => '/rails/workers' if Rails.env.development?
end
