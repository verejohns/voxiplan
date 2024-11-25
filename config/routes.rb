Rails.application.routes.draw do


  resource :organization do
    post :invite_member
    post :remove_member
    post :handle_calendar
    post :save_calendar
    post :remove_calendar
    get :calendar
  end

  post 'check_exist_ivr_url', to: 'ivrs#check_exist_url'
  post 'update_ivr_url', to: 'ivrs#update_url'
  post 'update_ivr_name', to: 'ivrs#update_name'

  ###testing of gocardless
  # get 'pricing/gocardless', to: 'pricing#pay_via_gocardless', as: :pay_via_gocardless
  ###testing end

  # resources :chat, only: [:index]
  match '/chat/:id', :to => 'chat#index', via: [:get], as: :chat_index
  match '/sms_campaign', :to => 'chat#sms', via: [:get], as: :sms_chat
  match '/send_sms_campaign', :to => 'chat#send_sms', via: [:post], as: :sms_send
  match '/fetch_agenda_slots', :to => 'chat#fetch_available_slots', via: [:post], as: :widget_slots
  match '/fetch_agenda_slots_for_schedule', :to => 'chat#fetch_available_slots_for_schedule', via: [:post], as: :widget_slots_for_schedule
  match '/validate_customer', :to => 'chat#validate_customer', via: [:post], as: :customer_verify
  match '/get_mandatory_question', :to => 'chat#get_mandatory_question', via: [:post], as: :get_mandatory_question
  match '/create_new_customer', :to => 'chat#create_customer', via: [:post], as: :create_customer_widget
  match '/update_customer', :to => 'chat#update_customer', via: [:post], as: :update_customer_widget
  match '/book_appointment', :to => 'chat#book_appointment', via: [:post], as: :book_appointment
  match '/cancel_appointment', :to => 'chat#cancel_appointment', via: [:post], as: :cancel_appointment
  match '/book_appointment_for_schedule', :to => 'chat#book_appointment_for_schedule', via: [:post], as: :book_appointment_for_schedule
  match '/linked_services_or_resources', :to => 'chat#linked_services_or_resources', via: [:post], as: :linked_services_or_resources
  match '/linked_questions', :to => 'chat#linked_questions', via: [:post], as: :linked_questions

  match '/pre_confirmation/cancelation/:id', :to => 'pre_confirmation#cancelation', via: [:get], as: :pre_confirmation_cancelation
  match '/pre_confirmation/acceptance/:id', :to => 'pre_confirmation#acceptance', via: [:get], as: :pre_confirmation_acceptance

  resources :pricing, only: [:index]
  # do
    # collection do
    #   get :pay_via_gocardless, as: :gocardless
    #   get :finalize_payment, as: :finalize_payment
    # end
  # end

  resources :plans, only: %i[index]

  # devise_for :clients, path: '',
  #           controllers: {sessions: "clients/sessions", registrations: "clients/registrations"},
  #           path_names:   { sign_in: 'login', sign_up: 'signup', edit: "settings/edit"}
  get '/auth/cronofy/callback', to: 'webhooks#cronofy'
  get '/cronofy/auth_callback', to: 'agenda_connect#connect'
  post '/cronofy/notification_callback/:client_id', to: 'notification#add_notification', as: :notification_callback
  post '/notification/get_notification', to: 'notification#get_notification'
  post '/chargebee_event_handler', to: 'webhooks#chargebee_event_handler', as: :chargebee_event_handler
  post '/event_trigger', to: 'webhooks#cronofy_event_trigger', as: :cronofy_event_trigger
  post '/status_callback', to: 'webhooks#twilio_status_callback', as: :status_callback

  resource :agenda_app do
    post :save_agenda_info
    post :save_agenda_info_old
    post :create_new_agenda
    post :get_calendars_of_agenda
    post :save_mobminder
    post :save_timify
  end

  # get 'activity', to: 'activity#index', as: 'activity_index'

  # resources :stats, path: '/activity/stats', only: [:index] do
  #   collection do
  #     match :search_stats, via: [:post, :get]
  #   end
  # end

  # resources :customers, path: 'activity/customers' do
  #   collection { post :import }
  # end
  # resource :activity, only: [:index]
  # resource :activity, only: [] do
  #   collection do
  #     resources :reports, only: [] do
  #       # collection do
  #       #   match :index, via:[:get, :post]
  #       # end
  #     end
  #   end
  # end

  resources :activity do
    collection do
      resources :reports, only: [:index] do
        collection do
          match :calls, via:[:get, :post]
          match :sms_list, via:[:get, :post], as: :sms
          match :url, via:[:get, :post]
          match :aggregates, via:[:get, :post]
          post :create_portal_session
          post :logout_portal_session
        end
      end
      resources :customers do
        collection { post :import }
        collection { post :get_contact }
        collection { post :send_phone_info }
        # post "exception_list" => "customers#exceptions"
      end
    end
  end

  match 'customers/exception_list' => 'customers#exceptions', :via => :post
  match 'customers/delete_multiple' => 'customers#destroy_multiple', :via => :post

  namespace :api, defaults: { format: :json } do
    scope :v1 do
      resources :sessions, only: [:create]
      resources :resources, only: [:index]
      resources :services, only: [:index]
      resources :preferences, only: [:index]
      resources :availability, only: [:index]
      resources :appointments, only: [:index, :create, :update, :destroy]
      resources :templates, only: [:index, :create]
      resources :customers, only: [:index, :create] do
        collection do
          match :auth_consumer, via: [:get, :post]
        end
      end
      get '/sessions', to: 'sessions#read'
      post '/send_email', to: 'sessions#send_email'
    end
  end

  resources :contact_us
  resources :clients do
    resources :ivrs do
      collection do
        get :change_ivr
      end
    end
    member do
      match :billing, via: [:post, :get]
      match :scheduling_appoinments_show, via: [:post, :get]
      match :edit_text, via: [:post, :get]
    end
    collection do
      patch :agenda_sign_up
      match :call_forwarding, via: [:post, :get]
      match :phone, via: [:get, :post]
      post :change_menu
      post :update_gtm_trigger
      post :get_client_detail
      get :my_ivrs
    end
  end

    resources :timify_credential, only: [] do
      collection do
        get :timify_cred
        post :timify_cred
        post :new_account_cred
        get :same_client
        get :different_client
        get :cancel_process
        get :check_timify_connection
        post :disconnect_timify_connection
      end
    end

  resources :integrations, only: [:index] do
    collection do
      match :connect_your_agenda, via:[:get, :post]
      match :select_agenda, via:[:get, :post]
      match :select_mobminder, via:[:get, :post]
      match :select_timify, via:[:get, :post]
      match :phone, via:[:get, :post]
      match :sms, via:[:get, :post]
      match :get_sms_channel, via:[:get]
      match :alpha_sms, via:[:get, :post]
      match :disconnect_calendar, via:[:post]
      match :update_calendar, via:[:post]
      match :update_conflict, via:[:post]
      match :change_dataserver, via:[:post]
      match :inbound_sms, via:[:post]
    end
  end

  resources :appoinments_scheduling, only: [:index, :create] do
    collection do

      get '/widget_preference/:ivr_id', to: 'appoinments_scheduling#widget_preference', as: 'widget_preference'
      get '/assistant_preference/:ivr_id', to: 'appoinments_scheduling#assistant_preference', as: 'assistant_preference'
      get '/general_preference/:ivr_id', to: 'appoinments_scheduling#general_preference', as: 'general_preference'
      get :get_resources
      match :assistant_preference, via:[:get]
      match :service_and_resource, via:[:get, :post]
      match :custom_texts, via:[:get, :post]
      match :save_language, via:[:post]
      match :save_business_hours, via:[:post]
      match :save_welcome_message, via:[:post]
      match :save_announce, via:[:post]
      match :save_followup, via:[:post]
      match :save_preferences, via:[:post]
      match :save_custom_texts, via:[:post]
      match :save_phone_menu, via:[:post]
      match :save_phone_menu_extentions, via:[:get, :post]
      match :new_phone_menu_extention, via:[:get]
      match :get_phone_menu_extention, via:[:get]
      match :get_extension, via:[:get]
      match :save_extension, via:[:post]
      match :delete_phone_menu_extension, via:[:post]
      match :remove_extension, via:[:post]
      match :set_default_extension, via:[:post]
      match :save_widget_setting, via:[:post]
      match :save_booking_option, via:[:post]
      match :save_branding, via:[:post]
      match :save_general_setting, via:[:post]
    end
  end

  resources :schedule_event do
    collection do
      post :get_events
      post :get_event_detail_info
      post :delete_event
      post :save_setting
      post :save_business_hours
      post :get_time_list
    end
  end

  resources :availablities do
    collection do
      post :save_schedule
      post :clone_schedule
      post :set_as_default
      post :delete_schedule
      post :save_availability
    end
  end

  resources :resources do
    member do
      put :toggle_enabled, as: :toggle_enabled
      post :change_enabled, as: :change_enabled
      post :get_calendar_info_of_resource
    end

    collection do
      post :get_availablities
      post :get_calendar_info_of_default
      post :update_resource
    end
  end
  resources :services do
    member do
      put :toggle_enabled, as: :toggle_enabled
      put :toggle_service_options_enabled, as: :toggle_service_options_enabled
    end

    collection do
      get '/new', to: 'services#new', as: :new_service
      get '/new_event/:ivr_id', to: 'services#new_event', as: :new_event
      get '/edit_event/(:id)', to: 'services#edit_event', as: :edit_event
      post :update_ordering, as: :update_ordering
      post :get_resources_of_selected_service, as: :get_resources_of_selected_service
      post :save_agenda_service_resource
      post :get_availablities
      post :save_as_schedule
      post :save_automation
      post :get_automation
      post :save_question
      post :automation_enabled
      post :get_slot_example
      post :number_list
      post :get_phone_countries
      post :order_number
      post :buy_no_address_number
      post :set_phone_type_of_ivr
      post :set_read_tutorial
      get :get_dependencies
      get '/(:filter)', to: 'services#index', as: :services
    end
  end

  resources :profiles do
    collection do
      post :close_account
      post :update_locale
      get :closed_account
    end
  end

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  #root 'clients#dashboard'
  get '/dashboard', to: 'clients#dashboard'
  get '/onboarding', to: 'home#onboarding'
  get '/old_onboarding', to: 'home#old_onboarding'
  get '/member_onboarding', to: 'home#member_onboarding'
  get '/set_server_region', to: 'home#set_server_region'
  get '/set_server_region_member', to: 'home#set_server_region_member'
  get '/verification_init', to: 'home#verification'
  get '/settings', to: 'clients/ory#reset'
  get '/recovery', to: 'clients/ory#recovery'
  get '/send_verification/:id', to: 'profiles#send_verification', as: :send_verification
  root 'home#index'
  match '/sms', to: 'webhooks#sms_webhook', via: [:get, :post]
  post '/recovery_client', to: 'clients/ory#recovery_client'
  get '/invitation/:id', to: 'clients/ory#invitation'
  get '/verification', to: 'clients/ory#verification'
  get '/ory_init', to: 'clients/ory#ory_init'
  get '/ory_error', to: 'clients/ory#error'
  get '/default_init', to: 'migration#default_init'
  get '/migrate_chargebee', to: 'migration#migrate_chargebee'
  get '/migrate_reminder_time', to: 'migration#migrate_reminder_time'
  get '/migrate_agenda_app_organization', to: 'migration#migrate_agenda_app_organization'
  get '/remove_clients', to: 'migration#remove_clients'
  get '/migrate_phone_info', to: 'migration#migrate_phone_info'
  get '/migrate_service', to: 'migration#migrate_service'
  get '/migrate_resource', to: 'migration#migrate_resource'

  get '/post_login', to: 'home#post_login'
  get '/post_registration', to: 'home#post_registration'
  get '/post_logout', to: 'home#post_logout'
  get '/post_settings', to: 'clients/ory#post_settings'
  get '/signup', to: 'clients/signup#new'
  get '/signin', to: 'clients/sessions#new'
  get '/logout_client', to: 'clients/ory#logout'
  post '/registration', to: 'clients/ory#registration'
  post '/check_email', to: 'home#check_email'
  post '/save_voxiplan_url', to: 'agenda_apps#save_voxiplan_url'
  post '/profile-edit', to: 'profiles#edit_profile'
  post '/set_organization', to: 'organizations#set_organization', as: :set_organization

  resources :webhooks, only: [] do
    collection do
      match :rasa, via: :all
      match :tropo, via: :all
      match :recording, via: :all
      match :timify_auth, via: :all
      match :voxi_sms, via: :all
      # match :twilio_sms, via: :all
      match :sms, via: :all
      # match :twilio_sms_status, via: :all
      # match :perform, via: :all
    end
  end

  resources :recordings, only: [:show]

  resources :automations do
  end

  # match '/recording', :to => 'webhooks#recording', via: [:all]
  match '/run/(:id)', :to => 'ivr#run', via: [:get, :post], as: :run_node
  get '/phone', to: redirect('voxiphone/index.html')
  get '/:id' => "shortener/shortened_urls#show"

  match '/s/:id', :to => 'chat#appointment', via: [:get], as: :appointment_widget

  # TODO: Only allow requests from Tropo
  scope format: true, constraints: { format: 'json' } do
    match '/welcome', :to => 'ivr#welcome', via: :post
    match '/menu1', :to => 'ivr#menu1', via: :post
    match '/handle_menu1', :to => 'ivr#handle_menu1', via: :post
    match '/handle_menu2', :to => 'ivr#handle_menu2', via: :post
    match '/handle_menu3', :to => 'ivr#handle_menu3', via: :post
    match '/create_appointment_with_phone', :to => 'ivr#create_appointment_with_phone', via: :post
    match '/send_sms', :to => 'ivr#send_sms', via: :post
    match '/receive_sms', :to => 'ivr#receive_sms', via: :post
    match '/hangup', :to => 'ivr#hangup', via: :post
  end
end
