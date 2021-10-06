Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get '/api/search/quote/:ticker' => 'search_quotes#show'
end
