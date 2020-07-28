# frozen_string_literal: true

require 'sidekiq/web' if Rails.env.development?

Rails.application.routes.draw do
  root to: proc { [200, { 'Content-Type' => 'application/json' }, [{ message: 'system operational' }.to_json]] }
  mount_devise_token_auth_for 'User', at: 'auth'
  namespace :v1 do
    resources :problems, only: %i[index show create update]
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
    scope 'problems/:problem_id' do
      scope module: 'problems' do
        resources :answers, only: %i[index]
      end
    end
  end
  if Rails.env.development?
    scope 'rails' do
      mount LetterOpenerWeb::Engine, at: 'browse_emails'
      mount Sidekiq::Web => 'workers'
    end
  end
end
