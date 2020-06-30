# frozen_string_literal: true

Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'
  root 'application#status'
  namespace :v1 do
    resources :interventions, only: %i[index show create update] do
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
end
