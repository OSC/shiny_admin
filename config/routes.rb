Rails.application.routes.draw do
  resources :articles
  resources :mapping

  root 'mapping#index'
end
