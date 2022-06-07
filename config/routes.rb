require 'resque/server'

Rails.application.routes.draw do
  post 'api/convert/' => 'api#convert'
  resources :startprocessing
  post 'startprocessing/start' => 'startprocessing#start'
  resources :av ,param: :slug do
     post 'updatevtt', on: :collection
     post 'makepublic', on: :collection
     get 'forcedalignment', on: :collection
     post 'forcedalignment', on: :collection
     get 'reprocess'
  end
  root 'av#index'
  post 'uploadfile' => 'av#uploadfile', as: 'uploadfile'
  get 'chooseposter/:slug' => 'av#chooseposter', as: 'chooseposter'
  get 'createposter/:slug' => 'av#createposter', as: 'createposter' 
  get 'embed/:slug' => 'av#embed', as: 'embed'
  get 'api/av/:av_id' => 'api#show_av', as: 'av_api'
  get 'transcript/:slug' => 'av#transcript', as: 'transcript'
  get 'api/search' => 'api#fulltextsearch'
  get 'api/context' => 'api#context', defaults: {format: :json}
  mount Resque::Server.new, at: "/resque"
end
