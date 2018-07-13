Rails.application.routes.draw do
  resources :mappings

  root 'mappings#index'
end
