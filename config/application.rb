require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
require 'rack/cors'
require 'csv'

# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Voxiplan
  class Application < Rails::Application
    Rails.application.routes.default_url_options[:host] = Rails.application.secrets.host

    paths['voxiphone'] = 'public/voxiphone'
    # paths["phone"] = Rails.root.join("public", "phone")
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.active_job.queue_adapter = :sucker_punch
    config.autoload_paths += Dir[Rails.root.join("app", "models", "nodes")]
    config.autoload_paths += Dir[Rails.root.join("app", "models", "agenda_apps")]
    config.autoload_paths += Dir[Rails.root.join("app", "models", "ivr_builders")]
    config.autoload_paths += Dir[Rails.root.join("lib", "**", "*")]
    config.autoload_paths += Dir[Rails.root.join("lib", "utils")]
    config.eager_load_paths << Rails.root.join('lib')
    config.autoload_paths << Rails.root.join('lib/api')
    # config.autoload_paths += Dir[Rails.root.join("lib", "api", "**", '*')]
    # remove devise error-fields wrapper
    config.action_view.field_error_proc = Proc.new { |html_tag, instance|
      html_tag
    }
    config.i18n.fallbacks = [:en]
    config.middleware.insert_before 0, Rack::Cors do
      allow do
         origins '*'
         resource '*'
      end
    end
    config.assets.initialize_on_precompile = false

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
