# frozen_string_literal: true

require 'sidekiq/web' if Rails.env.development?

Rails.application.routes.draw do
  root to: proc { [200, { 'Content-Type' => 'application/json' }, [{ message: 'system operational' }.to_json]] }

  namespace :v1 do
    mount_devise_token_auth_for 'User', at: 'auth', controllers: {
      confirmations: 'v1/auth_controller/confirmations',
      invitations: 'v1/users/invitations',
      passwords: 'v1/auth/passwords',
      registrations: 'v1/auth_controller/registrations',
      sessions: 'v1/auth/sessions'
    }

    scope :users do
      put 'send_sms_token', to: 'users#send_sms_token'
      patch 'verify_sms_token', to: 'users#verify_sms_token'
      scope module: 'users' do
        resource :invitations, only: %i[edit update]
        resources :invitations, only: %i[index create destroy]
      end
    end
    resources :users, only: %i[index show update destroy] do
      scope module: 'users' do
        resource :avatars, only: %i[create destroy]
      end
    end

    resources :interventions, only: %i[index show create update] do
      post 'clone', on: :member
      scope module: 'interventions' do
        resources :answers, only: %i[index]
        resources :invitations, only: %i[index create destroy]
      end
      patch 'sessions/position', to: 'sessions#position'
      resources :sessions, only: %i[index show create update destroy]
    end

    post 'sessions/:id/clone', to: 'sessions#clone', as: :clone_session
    scope 'sessions/:session_id', as: 'session' do
      patch 'questions/move', to: 'questions#move', as: :move_question
      scope module: 'sessions' do
        resources :invitations, only: %i[index create] do
          get 'resend', on: :member
        end
        resources :flows, only: %i[index]
      end
      resources :question_groups, only: %i[index show create update destroy] do
        member do
          patch :questions_change
          delete :remove_questions
          post :clone
          post :share
        end
        patch :position, on: :collection
      end
    end

    resources :question_groups, only: [] do
      resources :questions, only: %i[index show create update destroy]
    end

    post 'questions/:id/clone', to: 'questions#clone', as: :clone_question
    scope 'questions/:question_id', as: 'question' do
      resources :answers, only: %i[index show create]
      scope module: 'questions' do
        resource :images, only: %i[create destroy]
      end
    end

    resources :teams, only: %i[index show create update destroy]
  end

  if Rails.env.development?
    scope 'rails' do
      mount LetterOpenerWeb::Engine, at: '/browse_emails'
      mount Sidekiq::Web => '/workers'
    end
  end
end
