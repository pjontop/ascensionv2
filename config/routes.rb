# frozen_string_literal: true

Rails.application.routes.draw do
  get :landing, to: "landing#index"
  resources :rsvps, only: :create

  # Hack Club OpenID auth
  get "/auth/login", to: "auth#login", as: :login
  get "/auth/logout", to: "auth#logout", as: :logout
  match "/auth/hackclub/callback", to: "auth#callback", via: %i[get post]
  get "/auth/failure", to: "auth#failure"

  root "landing#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
