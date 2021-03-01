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
    resources :preview_session_users, only: :create

    resources :interventions, only: %i[index show create update] do
      post 'clone', on: :member
      scope module: 'interventions' do
        resources :answers, only: %i[index]
        resources :invitations, only: %i[index create destroy]
      end
      post 'sessions/:id/duplicate', to: 'sessions#duplicate', as: :duplicate_session
      patch 'sessions/position', to: 'sessions#position'
      resources :sessions, only: %i[index show create update destroy]
    end

    post 'sessions/:id/clone', to: 'sessions#clone', as: :clone_session
    scope 'sessions/:session_id', as: 'session' do
      patch 'questions/move', to: 'questions#move', as: :move_question
      delete 'delete_questions', to: 'questions#destroy'
      scope module: 'sessions' do
        resources :invitations, only: %i[index create] do
          get 'resend', on: :member
        end
        resources :report_templates, only: %i[index show create update destroy] do
          delete :remove_logo
        end
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

    scope module: :report_templates do
      scope 'report_templates/:report_template_id', as: :report_template do
        resources :sections, only: %i[index show create update destroy]
        resource :generate_pdf_preview, only: :create
      end

      scope module: :sections do
        scope 'report_templates/sections/:section_id', as: :report_template_section do
          resources :variants, only: %i[index show create update destroy] do
            delete :remove_image
          end
        end
      end
    end

    resources :question_groups, only: [] do
      resources :questions, only: %i[index show create update]
    end

    post 'questions/:id/clone', to: 'questions#clone', as: :clone_question
    scope 'questions/:question_id', as: 'question' do
      scope module: 'questions' do
        resource :images, only: %i[create destroy]
      end
    end

    resources :user_sessions, only: %i[create] do
      resources :questions, only: %i[index], module: 'user_sessions'
      resources :answers, only: %i[index show create], module: 'user_sessions'
    end

    resources :teams, only: %i[index show create update destroy] do
      delete :remove_researcher
      scope module: 'teams' do
        resources :invitations, only: :create
      end
    end
    get 'team_invitations/confirm', to: 'team_invitations#confirm', as: :team_invitations_confirm
    post :phonetic_preview, to: 'audio#create'
  end

  if Rails.env.development?
    scope 'rails' do
      mount LetterOpenerWeb::Engine, at: '/browse_emails'
      mount Sidekiq::Web => '/workers'
    end
  end
end
