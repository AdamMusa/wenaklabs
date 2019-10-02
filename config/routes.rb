# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  post 'webhooks' => 'webhooks#create'

  if AuthProvider.active.providable_type == DatabaseProvider.name
    # with local authentification we do not use omniAuth so we must differentiate the config
    devise_for :users, controllers: {
      registrations: 'registrations', sessions: 'sessions', confirmations: 'confirmations', passwords: 'passwords'
    }
  else
    devise_for :users, controllers: {
      registrations: 'registrations', sessions: 'sessions', confirmations: 'confirmations', passwords: 'passwords',
      omniauth_callbacks: 'users/omniauth_callbacks'
    }
    get '/sso-redirect', to: 'application#sso_redirect', as: :sso_redirect
  end


  ## The priority is based upon order of creation: first created -> highest priority.
  ## See how all your routes lay out with "rake routes".


  constraints user_agent: %r{facebookexternalhit/[0-9]|Twitterbot|Pinterest|Google.*snippet} do
    root to: 'social_bot#share', as: :bot_root
  end

  ## You can have the root of your site routed with "root"
  root 'application#index'

  namespace :api, as: nil, defaults: { format: :json } do
    resources :projects, only: %i[index show create update destroy] do
      collection do
        get :last_published
        get :search
        get :allowed_extensions
      end
    end
    resources :openlab_projects, only: :index
    resources :machines
    resources :components
    resources :themes
    resources :licences
    resources :admins, only: %i[index create destroy]
    resources :settings, only: %i[show update index], param: :name do
      patch '/bulk_update', action: 'bulk_update', on: :collection
    end
    resources :users, only: %i[index create]
    resources :members, only: %i[index show create update destroy] do
      get '/export_subscriptions', action: 'export_subscriptions', on: :collection
      get '/export_reservations', action: 'export_reservations', on: :collection
      get '/export_members', action: 'export_members', on: :collection
      put ':id/merge', action: 'merge', on: :collection
      post 'list', action: 'list', on: :collection
      get 'search/:query', action: 'search', on: :collection
      get 'mapping', action: 'mapping', on: :collection
    end
    resources :reservations, only: %i[show create index update]
    resources :notifications, only: %i[index show update] do
      match :update_all, path: '/', via: %i[put patch], on: :collection
      get 'polling', action: 'polling', on: :collection
      get 'last_unread', action: 'last_unread', on: :collection
    end
    resources :wallet, only: [] do
      get '/by_user/:user_id', action: 'by_user', on: :collection
      get :transactions, on: :member
      put :credit, on: :member
    end

    # for homepage
    get '/last_subscribed/:last' => 'members#last_subscribed'
    get '/feeds/twitter_timelines' => 'feeds#twitter_timelines'

    get 'pricing' => 'pricing#index'
    put 'pricing' => 'pricing#update'

    resources :prices, only: %i[index update] do
      post 'compute', on: :collection
    end
    resources :coupons
    post 'coupons/validate' => 'coupons#validate'
    post 'coupons/send' => 'coupons#send_to'

    resources :trainings_pricings, only: %i[index update]

    resources :availabilities do
      get 'machines/:machine_id', action: 'machine', on: :collection
      get 'trainings/:training_id', action: 'trainings', on: :collection
      get 'spaces/:space_id', action: 'spaces', on: :collection
      get 'reservations', on: :member
      get 'public', on: :collection
      get '/export_index', action: 'export_availabilities', on: :collection
      put ':id/lock', action: 'lock', on: :collection
    end

    resources :groups, only: %i[index create update destroy]
    resources :subscriptions, only: %i[show create update]
    resources :plans, only: %i[index create update destroy show]
    resources :slots, only: [:update] do
      put 'cancel', on: :member
    end

    resources :events do
      get 'upcoming/:limit', action: 'upcoming', on: :collection
    end

    resources :invoices, only: %i[index show create] do
      get 'download', action: 'download', on: :member
      post 'list', action: 'list', on: :collection
      get 'first', action: 'first', on: :collection
    end

    # for admin
    resources :trainings do
      get :availabilities, on: :member
    end
    resources :credits
    resources :categories
    resources :event_themes
    resources :age_ranges
    resources :statistics, only: [:index]
    resources :custom_assets, only: %i[show create update]
    resources :tags
    resources :stylesheets, only: [:show]
    resources :auth_providers do
      get 'mapping_fields', on: :collection
      get 'active', action: 'active', on: :collection
      post 'send_code', action: 'send_code', on: :collection
    end
    resources :abuses, only: %i[index create destroy]
    resources :open_api_clients, only: %i[index create update destroy] do
      patch :reset_token, on: :member
    end
    resources :price_categories
    resources :spaces
    resources :accounting_periods do
      get 'last_closing_end', on: :collection
      get 'archive', action: 'download_archive', on: :member
    end
    # export accounting data to csv or equivalent
    post 'accounting/export' => 'accounting_exports#export'

    # i18n
    # regex allows using dots in URL for 'state'
    get 'translations/:locale/:state' => 'translations#show', :constraints => { state: %r{[^/]+} }

    # XLSX exports
    get 'exports/:id/download' => 'exports#download'
    post 'exports/status' => 'exports#status'

    # Members CSV import
    resources :imports, only: [:show] do
      post 'members', action: 'members', on: :collection
    end

    # Fab-manager's version
    get 'version' => 'version#show'

    # payments handling
    post 'payments/confirm_payment' => 'payments/confirm_payment'
  end

  # rss

  namespace :rss, as: nil, defaults: { format: :xml } do
    resources :projects, only: [:index], as: 'rss_projects'
    resources :events, only: [:index], as: 'rss_events'
  end

  # open_api

  namespace :open_api do
    namespace :v1 do
      scope only: :index do
        resources :users
        resources :trainings
        resources :user_trainings
        resources :reservations
        resources :machines
        resources :bookable_machines
        resources :invoices do
          get :download, on: :member
        end
        resources :events
        resources :availabilities
      end
    end
  end

  %w[account event machine project subscription training user space].each do |path|
    post "/stats/#{path}/_search", to: "api/statistics##{path}"
    post "/stats/#{path}/export", to: "api/statistics#export_#{path}"
  end
  post '/stats/global/export', to: 'api/statistics#export_global'
  post '_search/scroll', to: 'api/statistics#scroll'

  match '/project_collaborator/:valid_token', to: 'api/projects#collaborator_valid', via: :get

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => '/admin/sidekiq'
  end

  apipie
end
