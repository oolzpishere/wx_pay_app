Rails.application.routes.draw do
  resources :products

  match 'products/invoke/:id', to: "products#invoke", via: [:get, :post]
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  post "notify", to: "products#notify"
end
