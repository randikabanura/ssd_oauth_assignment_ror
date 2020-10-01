require 'sidekiq/web'

Rails.application.routes.draw do
  get '/privacy', to: 'home#privacy'
  get '/terms', to: 'home#terms'
    authenticate :user, lambda { |u| u.admin? } do
      mount Sidekiq::Web => '/sidekiq'
    end


  resources :notifications, only: [:index]
  resources :announcements, only: [:index]
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: 'users/registrations' }
  root to: 'home#index'
  delete 'remove_subscription/:id', to: 'home#remove_subscription', as: :remove_subscription
  post 'video', to: 'home#video_search', as: :video_search
  get 'video/:video_id', to: 'home#video_search', as: :video_search_view

  get 'videos/liked_videos', to: 'video#liked_videos'
  get 'videos/disliked_videos', to: 'video#disliked_videos'
  get 'videos/subscriptions', to: 'video#my_subscriptions'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
