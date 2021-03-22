# frozen_string_literal: true

require 'sidekiq/web' if ENV['SIDEKIQ_WEB_INTERFACE'] == '1'

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
      get 'researchers', to: 'users#researchers'
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

    scope 'interventions/:interventions_id', as: 'intervention' do
      scope module: 'interventions' do
        resource :logo, only: %i[create destroy]
      end
    end

    post 'sessions/:id/clone', to: 'sessions#clone', as: :clone_session
    scope 'sessions/:session_id', as: 'session' do
      post 'questions/clone_multiple', to: 'questions#clone_multiple', as: :clone_multiple_questions
      patch 'questions/move', to: 'questions#move', as: :move_question
      delete 'delete_questions', to: 'questions#destroy'
      scope module: 'sessions' do
        resources :invitations, only: %i[index create] do
          get 'resend', on: :member
        end
        resources :sms_plans, only: :index
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

    scope module: 'sms_plans' do
      scope 'sms_plans/:sms_plan_id', as: :sms_plan do
        resources :variants
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
    post 'questions/share', to: 'questions#share', as: :share_questions
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
    resources :sms_plans do
      post 'clone', on: :member
    end

    resources :generated_reports, only: :index
  end

  if Rails.env.development?
    scope 'rails' do
      mount LetterOpenerWeb::Engine, at: '/browse_emails'
    end
  end

  if ENV['SIDEKIQ_WEB_INTERFACE'] == '1'
    scope 'rails' do
      Sidekiq::Web.use Rack::Auth::Basic do |username, password|
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_USERNAME'])) &
          ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_PASSWORD']))
      end
      mount Sidekiq::Web => '/workers'
    end
  end
end
