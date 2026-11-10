# frozen_string_literal: true

resources :smartfull_users, only: [:index, :new, :create, :edit, :update] do
  member do
    post :lock
    post :unlock
  end
end
