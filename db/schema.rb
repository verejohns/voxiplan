# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2022_12_01_154936) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "admins", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "agenda_apps", id: :serial, force: :cascade do |t|
    t.string "type"
    t.string "ss_schedule_id"
    t.string "ss_checksum"
    t.text "ss_default_params"
    t.string "mm_login"
    t.string "mm_pwd"
    t.string "mm_kid"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ivr_id"
    t.string "timify_email"
    t.string "timify_access_token"
    t.string "cronofy_access_token"
    t.string "cronofy_refresh_token"
    t.string "cronofy_profile_id"
    t.string "cronofy_provider_name"
    t.string "cronofy_profile_name"
    t.json "default_resource_availability", default: {"mon"=>[{"from"=>"09:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}
    t.string "cronofy_account_id"
    t.string "calendar_id"
    t.string "calendar_account"
    t.string "conflict_calendars"
    t.string "timify_company_id"
    t.string "channel_id"
    t.string "organization_id"
    t.index ["client_id"], name: "index_agenda_apps_on_client_id"
    t.index ["ivr_id"], name: "index_agenda_apps_on_ivr_id"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
  end

  create_table "analytics", id: :serial, force: :cascade do |t|
    t.datetime "click_time"
    t.string "click_device"
    t.string "click_Browser"
    t.string "click_Language"
    t.string "click_geo_location"
    t.integer "analysable_id"
    t.string "analysable_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysable_type", "analysable_id"], name: "index_analytics_on_analysable_type_and_analysable_id"
  end

  create_table "answers", id: :serial, force: :cascade do |t|
    t.string "question_text"
    t.string "text"
    t.string "customer_id"
    t.string "appointment_id"
    t.string "question_type", default: ""
  end

  create_table "application_calendars", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "organization_id"
    t.integer "client_id"
    t.string "calendar_id"
    t.string "access_token"
    t.string "refresh_token"
    t.string "application_sub"
    t.string "calendar_name"
    t.string "conflict_calendars"
  end

  create_table "appointments", id: :serial, force: :cascade do |t|
    t.string "caller_id"
    t.string "caller_name"
    t.datetime "time"
    t.string "tropo_session_id"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.integer "ivr_id"
    t.string "resource_id"
    t.string "service_id"
    t.string "event_id"
    t.string "status"
    t.integer "rescheduled_count"
    t.index ["client_id"], name: "index_appointments_on_client_id"
  end

  create_table "availabilities", force: :cascade do |t|
    t.bigint "schedule_template_id"
    t.json "availabilities", default: {"mon"=>[{"from"=>"09:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}
    t.json "overrides"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["schedule_template_id"], name: "index_availabilities_on_schedule_template_id"
  end

  create_table "billings", force: :cascade do |t|
    t.bigint "client_id"
    t.string "category"
    t.string "phone_type"
    t.decimal "cost_price", precision: 10, scale: 5
    t.string "cost_price_unit"
    t.decimal "profit_margin", precision: 5, scale: 2
    t.decimal "selling_price", precision: 10, scale: 5
    t.string "selling_price_unit"
    t.decimal "selling_price_eur", precision: 10, scale: 5
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "quantity"
    t.integer "ivr_id"
    t.index ["client_id"], name: "index_billings_on_client_id"
  end

  create_table "calendar_settings", force: :cascade do |t|
    t.bigint "client_id"
    t.string "slot_duration", default: "00:30:00"
    t.string "snap_duration", default: "00:30:00"
    t.string "min_time", default: "00:00:00"
    t.string "max_time", default: "24:00:00"
    t.string "hidden_days", default: "0,6"
    t.string "first_day", default: "1"
    t.string "time_format", default: "12"
    t.json "availabilities", default: {"mon"=>[{"from"=>"09:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_calendar_settings_on_client_id"
  end

  create_table "calls", id: :serial, force: :cascade do |t|
    t.string "tropo_session_id"
    t.string "tropo_call_id"
    t.string "caller_id"
    t.string "caller_name"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recording_file_name"
    t.string "recording_content_type"
    t.integer "recording_file_size"
    t.datetime "recording_updated_at"
    t.integer "ivr_id"
    t.datetime "appointment_time"
    t.string "to_state"
    t.string "caller_country"
    t.string "caller_state"
    t.string "to_zip"
    t.string "caller_zip"
    t.string "to_country"
    t.string "called_zip"
    t.string "called_city"
    t.string "called_country"
    t.string "caller_city"
    t.string "from_country"
    t.string "to_city"
    t.string "from_city"
    t.string "called_state"
    t.string "from_zip"
    t.string "from_state"
    t.string "call_type"
    t.string "appointment_type"
    t.string "client_type"
    t.integer "recordings_count"
    t.integer "text_messages_count"
    t.string "to"
    t.string "from"
    t.string "forwarded_from"
    t.datetime "finished_at"
    t.datetime "forwarded_at"
    t.boolean "call_for_appointment"
    t.text "data"
    t.integer "duration"
    t.string "entered_number"
    t.string "parent_call_sid"
    t.integer "minutes"
    t.decimal "phone_price", precision: 5, scale: 2
    t.string "phone_type"
    t.boolean "is_sip"
    t.decimal "margin", precision: 5, scale: 2
    t.decimal "sale_price", precision: 5, scale: 2
    t.index ["client_id"], name: "index_calls_on_client_id"
    t.index ["ivr_id"], name: "index_calls_on_ivr_id"
  end

  create_table "clients", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "schedule_id"
    t.string "checksum"
    t.json "ivr_text", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "agent_number"
    t.string "sip"
    t.string "voice"
    t.text "default_params"
    t.boolean "confirmation_sms", default: true
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "industry"
    t.string "country"
    t.integer "role"
    t.string "preferred_locale"
    t.string "first_name"
    t.string "last_name"
    t.string "company"
    t.json "agenda_sign_up_fields", default: {}
    t.string "identifier"
    t.string "uid"
    t.string "appointments_be_suggested"
    t.string "time_zone"
    t.string "phone_country"
    t.string "billing_add_1"
    t.string "billing_add_2"
    t.string "billing_city"
    t.string "billing_state"
    t.integer "billing_zip"
    t.string "billing_country"
    t.string "billing_first_name"
    t.string "billing_last_name"
    t.string "tax_id"
    t.string "customer_type"
    t.string "billing_company_name"
    t.boolean "is_welcomed"
    t.string "address_one"
    t.string "address_two"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "language"
    t.string "country_code"
    t.string "date_format"
    t.string "menu_type"
    t.boolean "gtm_triggered"
    t.string "currency_code", default: "USD"
    t.string "avatar_file_name"
    t.string "avatar_content_type"
    t.bigint "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.string "ory_id"
    t.string "server_region"
    t.boolean "receive_email", default: true
    t.boolean "email_verified"
    t.boolean "read_tutorial", default: false
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["reset_password_token"], name: "index_clients_on_reset_password_token", unique: true
    t.index ["uid"], name: "index_clients_on_uid", unique: true
  end

  create_table "clients_roles", id: false, force: :cascade do |t|
    t.integer "client_id"
    t.integer "role_id"
    t.index ["client_id", "role_id"], name: "index_clients_roles_on_client_id_and_role_id"
    t.index ["client_id"], name: "index_clients_roles_on_client_id"
    t.index ["role_id"], name: "index_clients_roles_on_role_id"
  end

  create_table "contacts", id: :serial, force: :cascade do |t|
    t.integer "customer_id"
    t.string "phone"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_type"
    t.integer "client_id"
    t.boolean "exceptional_number"
    t.index ["client_id"], name: "index_contacts_on_client_id"
  end

  create_table "conversations", id: :serial, force: :cascade do |t|
    t.integer "client_id"
    t.integer "ivr_id"
    t.string "from"
    t.string "to"
    t.datetime "expire_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session_id"
    t.index ["client_id"], name: "index_conversations_on_client_id"
    t.index ["ivr_id"], name: "index_conversations_on_ivr_id"
    t.index ["session_id"], name: "index_conversations_on_session_id"
  end

  create_table "customers", id: :serial, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "gender"
    t.string "birthday"
    t.string "city"
    t.string "street"
    t.string "zipcode"
    t.string "phone_country"
    t.string "phone_number"
    t.string "eid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.string "recorded_name_url"
    t.integer "client_id"
    t.string "fixed_line_num"
    t.boolean "created_on_agenda"
    t.datetime "last_active_at"
    t.string "country"
    t.string "phone_number1"
    t.string "phone_number2"
    t.string "phone_number3"
    t.string "phone_country1"
    t.string "phone_country2"
    t.string "phone_country3"
    t.boolean "is_transfer", default: true
    t.index ["client_id"], name: "index_customers_on_client_id"
  end

  create_table "event_triggers", force: :cascade do |t|
    t.string "event_id"
    t.string "trigger_id"
    t.integer "offset_time"
    t.string "offset_duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "identifiers", id: :serial, force: :cascade do |t|
    t.string "identifier"
    t.integer "ivr_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_type"
    t.decimal "phone_price", precision: 5, scale: 2
    t.index ["ivr_id"], name: "index_identifiers_on_ivr_id"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.string "organization_id"
    t.string "to_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "enable_calendar"
    t.string "role"
  end

  create_table "ivrs", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "client_id"
    t.integer "start_node_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "confirmation_sms", default: true
    t.string "voice"
    t.string "agent_number"
    t.string "uid"
    t.json "preference", default: {"service_or_resource"=>"Services"}
    t.string "voice_locale"
    t.json "templates", default: {}
    t.boolean "use_branding", default: false
    t.text "description"
    t.string "logo_file_name"
    t.string "logo_content_type"
    t.bigint "logo_file_size"
    t.datetime "logo_updated_at"
    t.string "booking_url"
    t.boolean "remove_voxiplan_branding", default: false
    t.string "message", default: "en-US-Neural2-F"
    t.string "message_locale", default: "en-US"
    t.string "assistant_name", default: "Laura"
    t.string "organization_id"
    t.string "google_voice_locale", default: ""
    t.string "message_section", default: "spoken"
    t.index ["client_id"], name: "index_ivrs_on_client_id"
    t.index ["start_node_id"], name: "index_ivrs_on_start_node_id"
    t.index ["uid"], name: "index_ivrs_on_uid", unique: true
  end

  create_table "nodes", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "type"
    t.string "next"
    t.json "text"
    t.string "voice"
    t.integer "timeout"
    t.integer "tries"
    t.boolean "required"
    t.boolean "interruptible"
    t.string "timeout_next"
    t.string "invalid_next"
    t.json "choices"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "input_min_length"
    t.integer "input_max_length"
    t.string "input_terminator"
    t.json "to"
    t.string "from"
    t.string "method_name"
    t.json "parameters"
    t.json "results"
    t.boolean "enabled", default: true
    t.boolean "can_enable", default: false
    t.json "email_subject", default: {}
    t.json "business_hours", default: {}
    t.string "condition"
    t.string "left_operand"
    t.json "right_operand", default: []
    t.integer "ivr_id"
    t.string "ext_prefix"
    t.string "ext_title"
    t.string "ext_action"
    t.string "try1_invalid"
    t.string "try1_timeout"
    t.json "next_nodes"
    t.boolean "notify_hangup", default: true
    t.json "context"
    t.integer "schedule_template_id", default: 0
    t.json "overrides"
    t.index ["ivr_id"], name: "index_nodes_on_ivr_id"
    t.index ["name"], name: "index_nodes_on_name"
  end

  create_table "nodes_users", id: false, force: :cascade do |t|
    t.integer "node_id", null: false
    t.integer "user_id", null: false
    t.index ["node_id", "user_id"], name: "index_nodes_users_on_node_id_and_user_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "client_id"
    t.string "channel_id"
    t.datetime "changes_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "client_id"
    t.string "chargebee_subscription_id"
    t.string "chargebee_subscription_plan"
    t.integer "chargebee_seats"
    t.string "chargebee_subscription_period"
  end

  create_table "payment_details", id: :serial, force: :cascade do |t|
    t.string "customer_id"
    t.string "subscription_id"
    t.string "payment_via"
    t.integer "client_id"
    t.string "mandate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "phone_numbers", id: :serial, force: :cascade do |t|
    t.string "number"
    t.string "friendly_name"
    t.boolean "sms"
    t.boolean "voice"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_type"
    t.boolean "inbound_sms", default: false
    t.index ["client_id"], name: "index_phone_numbers_on_client_id"
  end

  create_table "plans", id: :serial, force: :cascade do |t|
    t.string "plan_id"
    t.string "name"
    t.string "amount"
    t.string "interval"
    t.string "currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "num_of_active_users"
  end

  create_table "question_options", id: :serial, force: :cascade do |t|
    t.string "text"
    t.string "question_id"
    t.integer "orderno"
  end

  create_table "questions", id: :serial, force: :cascade do |t|
    t.string "text"
    t.string "answer_type"
    t.string "service_id"
    t.boolean "enabled"
    t.boolean "mandatory"
    t.integer "orderno"
  end

  create_table "rake_task_migrations", id: :serial, force: :cascade do |t|
    t.string "version"
    t.integer "runtime"
    t.datetime "migrated_on"
  end

  create_table "recordings", id: :serial, force: :cascade do |t|
    t.string "file_name"
    t.string "url"
    t.integer "call_id"
    t.string "eid"
    t.string "duration"
    t.string "status"
    t.string "started_at"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "node_name"
    t.string "transcription"
    t.index ["call_id"], name: "index_recordings_on_call_id"
  end

  create_table "reminders", id: :serial, force: :cascade do |t|
    t.string "advance_time_offset"
    t.string "advance_time_duration"
    t.string "time"
    t.boolean "sms"
    t.boolean "email"
    t.integer "client_id"
    t.integer "ivr_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "text"
    t.string "sms_text"
    t.string "email_subject"
    t.integer "service_id"
    t.boolean "enabled"
    t.boolean "is_include_cancel_link", default: true
    t.boolean "is_include_agenda", default: false
    t.string "time_duration", default: "minutes"
    t.string "email_subject_host"
    t.string "text_host"
    t.index ["client_id"], name: "index_reminders_on_client_id"
    t.index ["ivr_id"], name: "index_reminders_on_ivr_id"
  end

  create_table "resource_services", id: :serial, force: :cascade do |t|
    t.integer "resource_id"
    t.integer "service_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id"], name: "index_resource_services_on_resource_id"
    t.index ["service_id"], name: "index_resource_services_on_service_id"
  end

  create_table "resources", id: :serial, force: :cascade do |t|
    t.integer "ivr_id"
    t.string "eid"
    t.string "ename"
    t.string "name"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "agenda_id"
    t.boolean "is_local"
    t.string "dependent_ids", default: [], array: true
    t.integer "resource_id"
    t.string "agenda_type"
    t.json "availability", default: {"mon"=>[{"from"=>"09:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}
    t.boolean "use_default_availability", default: true
    t.string "calendar_id"
    t.boolean "is_default", default: false
    t.integer "client_id"
    t.integer "order_id"
    t.json "preference", default: {"enabled"=>"false", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"true", "sms_enabled"=>"true", "ai_phone_assistant_enabled"=>"false"}
    t.boolean "disable_schedule", default: false
    t.string "application_calendar_id"
    t.string "application_access_token"
    t.string "application_refresh_token"
    t.string "application_sub"
    t.boolean "is_user_account"
    t.string "conflict_calendars"
    t.integer "schedule_template_id", default: 0
    t.json "overrides"
    t.string "calendar_type", default: "my_calendar"
    t.string "my_calendar_type", default: "default"
    t.integer "team_calendar_client_id"
    t.index ["client_id"], name: "index_resources_on_client_id"
    t.index ["eid"], name: "index_resources_on_eid"
    t.index ["ivr_id"], name: "index_resources_on_ivr_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.integer "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource_type_and_resource_id"
  end

  create_table "schedule_templates", force: :cascade do |t|
    t.string "template_name"
    t.boolean "is_default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "client_id"
    t.index ["client_id"], name: "index_schedule_templates_on_client_id"
  end

  create_table "service_notifications", force: :cascade do |t|
    t.bigint "client_id"
    t.bigint "service_id"
    t.string "automation_type"
    t.string "subject"
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "use_sms_invitee"
    t.boolean "use_sms_host"
    t.boolean "is_include_cancel_link"
    t.boolean "use_email_host"
    t.boolean "is_include_cancel_link_host"
    t.string "text_host"
    t.index ["client_id"], name: "index_service_notifications_on_client_id"
    t.index ["service_id"], name: "index_service_notifications_on_service_id"
  end

  create_table "services", id: :serial, force: :cascade do |t|
    t.integer "ivr_id"
    t.string "eid"
    t.string "ename"
    t.string "name"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "agenda_id"
    t.boolean "is_local"
    t.string "dependent_ids", default: [], array: true
    t.integer "service_id"
    t.string "agenda_type"
    t.integer "duration", default: 30
    t.boolean "is_default", default: false
    t.boolean "random_resource", default: false
    t.integer "client_id"
    t.integer "order_id"
    t.float "price"
    t.integer "buffer", default: 0
    t.boolean "random_resource_widget"
    t.json "preference", default: {"pre_confirmation"=>"false", "enabled"=>"false", "widget_enabled"=>"false", "phone_assistant_enabled"=>"false", "chat_enabled"=>"false", "sms_enabled"=>"false", "ai_phone_assistant_enabled"=>"false"}
    t.json "availability", default: {"mon"=>[{"from"=>"09:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}
    t.boolean "use_default_availability", default: true
    t.boolean "disable_schedule", default: false
    t.string "other_name"
    t.integer "schedule_template_id", default: 0
    t.json "overrides"
    t.string "response_format", default: "slots"
    t.integer "start_interval", default: 30
    t.string "resource_distribution", default: "invitee"
    t.integer "buffer_before", default: 0
    t.integer "buffer_after", default: 0
    t.index ["client_id"], name: "index_services_on_client_id"
    t.index ["eid"], name: "index_services_on_eid"
    t.index ["ivr_id"], name: "index_services_on_ivr_id"
  end

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "shortened_urls", id: :serial, force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type", limit: 20
    t.text "url", null: false
    t.string "unique_key", limit: 10, null: false
    t.string "category"
    t.integer "use_count", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "short_url"
    t.index ["category"], name: "index_shortened_urls_on_category"
    t.index ["owner_id", "owner_type"], name: "index_shortened_urls_on_owner_id_and_owner_type"
    t.index ["unique_key"], name: "index_shortened_urls_on_unique_key", unique: true
    t.index ["url"], name: "index_shortened_urls_on_url"
  end

  create_table "subscriptions", id: :serial, force: :cascade do |t|
    t.string "subscription_id"
    t.string "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "event_id"
    t.string "membership"
    t.string "period"
    t.integer "seats"
    t.integer "amount"
  end

  create_table "test_identifiers", id: :serial, force: :cascade do |t|
    t.string "identifier"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "text_messages", id: :serial, force: :cascade do |t|
    t.string "to"
    t.string "content"
    t.string "sms_type"
    t.integer "call_id"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "error_message"
    t.string "from"
    t.boolean "incoming"
    t.string "eid"
    t.datetime "time_sent"
    t.integer "conversation_id"
    t.integer "status"
    t.integer "ivr_id"
    t.string "twilio_status"
    t.decimal "sms_price", precision: 5, scale: 2
    t.integer "segment"
    t.string "sid"
    t.boolean "is_twilio"
    t.decimal "margin", precision: 5, scale: 2
    t.decimal "sale_price", precision: 5, scale: 2
    t.index ["call_id"], name: "index_text_messages_on_call_id"
    t.index ["conversation_id"], name: "index_text_messages_on_conversation_id"
    t.index ["ivr_id"], name: "index_text_messages_on_ivr_id"
  end

  create_table "tropo_webhooks", id: :serial, force: :cascade do |t|
    t.string "resource"
    t.string "name"
    t.string "payload_id"
    t.string "event"
    t.string "call_id"
    t.string "reason"
    t.string "application_type"
    t.integer "message_count"
    t.string "parent_call_id"
    t.string "parent_session_id"
    t.string "session_id"
    t.string "network"
    t.datetime "initiation_time"
    t.integer "duration"
    t.string "account_id"
    t.string "start_url"
    t.string "from"
    t.string "to"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "application_id"
    t.string "application_name"
    t.string "direction"
    t.string "status"
    t.json "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "client_id"
    t.integer "duration_minutes"
    t.integer "internal_call_id"
    t.index ["client_id"], name: "index_tropo_webhooks_on_client_id"
    t.index ["internal_call_id"], name: "index_tropo_webhooks_on_internal_call_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "number"
    t.string "sip"
    t.string "sip_login"
    t.string "sip_pwd"
    t.string "sip_host"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uid"
    t.string "country"
    t.boolean "is_default"
    t.json "availability", default: {"mon"=>[{"from"=>"00:00", "to"=>"24:00"}], "tue"=>[{"from"=>"00:00", "to"=>"24:00"}], "wed"=>[{"from"=>"00:00", "to"=>"24:00"}], "thu"=>[{"from"=>"00:00", "to"=>"24:00"}], "fri"=>[{"from"=>"00:00", "to"=>"24:00"}], "sat"=>[{"from"=>"00:00", "to"=>"24:00"}], "sun"=>[{"from"=>"00:00", "to"=>"24:00"}]}
    t.index ["client_id"], name: "index_users_on_client_id"
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  create_table "version_associations", id: :serial, force: :cascade do |t|
    t.integer "version_id"
    t.string "foreign_key_name", null: false
    t.integer "foreign_key_id"
    t.string "foreign_type"
    t.index ["foreign_key_name", "foreign_key_id", "foreign_type"], name: "index_version_associations_on_foreign_key"
    t.index ["version_id"], name: "index_version_associations_on_version_id"
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at"
    t.text "object_changes"
    t.integer "transaction_id"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["transaction_id"], name: "index_versions_on_transaction_id"
  end

  create_table "voxi_sessions", id: :serial, force: :cascade do |t|
    t.string "platform"
    t.text "data"
    t.integer "ivr_id"
    t.integer "client_id"
    t.integer "call_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session_id"
    t.string "caller_id"
    t.integer "customer_id"
    t.string "service_id"
    t.string "resource_id"
    t.index ["call_id"], name: "index_voxi_sessions_on_call_id"
    t.index ["client_id"], name: "index_voxi_sessions_on_client_id"
    t.index ["ivr_id"], name: "index_voxi_sessions_on_ivr_id"
  end

  create_table "webhook_call_details", id: :serial, force: :cascade do |t|
    t.string "email"
    t.text "access_token"
    t.json "auth_data"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_webhook_call_details_on_client_id"
  end

  add_foreign_key "agenda_apps", "clients"
  add_foreign_key "agenda_apps", "ivrs"
  add_foreign_key "appointments", "clients"
  add_foreign_key "availabilities", "schedule_templates"
  add_foreign_key "billings", "clients"
  add_foreign_key "calendar_settings", "clients"
  add_foreign_key "calls", "clients"
  add_foreign_key "calls", "ivrs"
  add_foreign_key "contacts", "clients"
  add_foreign_key "conversations", "clients"
  add_foreign_key "conversations", "ivrs"
  add_foreign_key "customers", "clients"
  add_foreign_key "identifiers", "ivrs"
  add_foreign_key "ivrs", "clients"
  add_foreign_key "ivrs", "nodes", column: "start_node_id"
  add_foreign_key "nodes", "ivrs"
  add_foreign_key "phone_numbers", "clients"
  add_foreign_key "recordings", "calls"
  add_foreign_key "resource_services", "resources"
  add_foreign_key "resource_services", "services"
  add_foreign_key "resources", "clients"
  add_foreign_key "resources", "ivrs"
  add_foreign_key "schedule_templates", "clients"
  add_foreign_key "service_notifications", "clients"
  add_foreign_key "service_notifications", "services"
  add_foreign_key "services", "clients"
  add_foreign_key "services", "ivrs"
  add_foreign_key "text_messages", "calls"
  add_foreign_key "text_messages", "conversations"
  add_foreign_key "text_messages", "ivrs"
  add_foreign_key "tropo_webhooks", "clients"
  add_foreign_key "voxi_sessions", "calls"
  add_foreign_key "voxi_sessions", "clients"
  add_foreign_key "voxi_sessions", "ivrs"
end
