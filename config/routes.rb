Rails.application.routes.draw do
  resources :mappings do
    collection do
      put 'fix_permissions'
    end
  end

  root 'mappings#index'
end
