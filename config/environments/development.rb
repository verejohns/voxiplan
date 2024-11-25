Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  config.allow_concurrency = true

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => 'public, max-age=172800'
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  # For Docker, use the following values:
  #config.web_console.whitelisted_ips ='172.20.0.1'

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }

  ActionMailer::Base.smtp_settings = {
    :user_name => ENV["SENDGRID_USERNAME"], # This is the string literal 'apikey', NOT the ID of your API key
    :password => ENV["SENDGRID_PASSWORD"], # This is the secret sendgrid API key which was issued during API key creation
    :domain => 'yourdomain.com',
    :address => 'smtp.sendgrid.net',
    :port => 587,
    :authentication => :plain,
    :enable_starttls_auto => true
  }

  config.cache_store = :mem_cache_store,
  (ENV["MEMCACHEDCLOUD_SERVERS"] || "").split(","),
  {:username => ENV["MEMCACHEDCLOUD_USERNAME"],
   :password => ENV["MEMCACHEDCLOUD_PASSWORD"],
   :failover => true
  }

  # config.paperclip_defaults = {
  #    storage: :s3,
  #    bucket: ENV["SPACE_BUCKET_NAME"],
  #    s3_credentials: {
  #      access_key_id: ENV["SPACE_KEY"],
  #      secret_access_key: ENV["SPACE_SECRET"]
  #    },
  #    s3_host_name: ENV["SPACE_HOSTNAME"],
  #    s3_host_alias: "#{ENV["SPACE_BUCKET_NAME"]}.#{ENV["SPACE_HOSTNAME"]}",
  #    s3_region: ENV["SPACE_REGION"],
  #    s3_protocol: :https,
  #    s3_options: {
  #      endpoint: "https://#{ENV["SPACE_HOSTNAME"]}",
  #    },
  #    url: ":s3_alias_url",
  #    path: "/assets/:class/:attachment/:style/:filename",
  #  }

  # config.paperclip_defaults = {
  #     storage: :s3,
  #     url: ENV.fetch('SPACE_ENDPOINT'),
  #     s3_region: ENV.fetch('SPACE_REGION'),
  #     s3_host_name: 'nyc3.digitaloceanspaces.com',
  #     s3_credentials: {
  #       bucket: ENV.fetch('SPACE_BUCKET_NAME'),
  #       access_key_id: ENV.fetch('SPACE_KEY'),
  #       secret_access_key: ENV.fetch('SPACE_SECRET'),
  #     }
  # }
end
