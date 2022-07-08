Rails.application.routes.draw do
  resources :violations, only: :index
end
