# frozen_string_literal: true

Rails.application.routes.draw do
  resources :requests, controller: "processing_requests", only: %i[create show] do
    member do
      post :cancel
    end
  end
end
