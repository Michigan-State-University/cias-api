# frozen_string_literal: true

require 'sidekiq/web' if Rails.env.development?

Rails.application.routes.draw do
  root to: proc { [200, { 'Content-Type' => 'application/json' }, [{ message: 'system operational' }.to_json]] }

  namespace :v1 do
    mount_devise_token_auth_for 'User', at: 'auth'

    resources :users, only: %i[index show update destroy]

    resources :problems, only: %i[index show create update] do
      post 'clone', on: :member
      scope module: 'problems' do
        resources :answers, only: %i[index]
        resources :users, only: %i[index create destroy]
      end
      patch 'interventions/position', to: 'interventions#position'
      resources :interventions, only: %i[index show create update]
    end

    post 'interventions/:id/clone', to: 'interventions#clone', as: :clone_intervention
    scope 'interventions/:intervention_id', as: 'intervention' do
      patch 'questions/position', to: 'questions#position'
      resources :questions, only: %i[index show create update destroy]
    end

    post 'questions/:id/clone', to: 'questions#clone', as: :clone_question
    scope 'questions/:question_id', as: 'question' do
      resources :answers, only: %i[index show create]
      scope module: 'questions' do
        resource :images, only: %i[create destroy]
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
