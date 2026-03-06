Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth
  get "/login", to: "sessions#new", as: :login
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  get "/signup", to: "registrations#new", as: :signup
  post "/signup", to: "registrations#create"

  # Settings
  get "/settings", to: "settings#show", as: :settings
  patch "/settings", to: "settings#update"

  # Admin
  get "/admin", to: "admin#dashboard", as: :admin_dashboard

  # Projects
  resources :projects, only: %i[index show edit update]

  # Slack webhook
  post "/slack/events", to: "slack_webhooks#events"

  root "projects#index"
end
