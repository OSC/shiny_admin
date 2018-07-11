Rails.application.routes.draw do
  resources :mapping

  root 'mapping#index'
end
