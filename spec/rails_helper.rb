# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rspec'
# Add additional requires below this line. Rails is not loaded until this point!

require 'vcr'
require 'sucker_punch/testing/inline'

TIMIFY_API_KEY      = ENV['TIMIFY_API_KEY']
TIMIFY_API_SECRET   = ENV['TIMIFY_API_SECRET']
TIMIFY_ACCESS_TOKEN = ENV['TIMIFY_ACCESS_TOKEN']
TIMIFY_APP_ID       = ENV['TIMIFY_APP_ID']
TIMIFY_APP_SECRET   = ENV['TIMIFY_APP_SECRET']
TIMIFY_TEST_COMPANY_ID = ENV['TIMIFY_TEST_COMPANY_ID']
MAIL_BCC = ENV['MAIL_BCC']

CRONOFY_CLIENT_ID = ENV['CRONOFY_CLIENT_ID']
CRONOFY_CLIENT_SECRET = ENV['CRONOFY_CLIENT_SECRET']
CRONOFY_ACCESS_TOKEN = ENV['CRONOFY_ACCESS_TOKEN']
CRONOFY_REFRESH_TOKEN = ENV['CRONOFY_REFRESH_TOKEN']
CRONOFY_PROFILE_ID = ENV['CRONOFY_PROFILE_ID']

SS_SCHEDULE_ID = ENV['SS_SCHEDULE_ID']
SS_CHECKSUM    = ENV['SS_CHECKSUM']

MM_LOGIN    = ENV['MM_LOGIN']
MM_PASSWORD = ENV['MM_PASSWORD']
MM_KEY      = ENV['MM_KEY']

HOST        = ENV['DOMAIN']

ORY_SDK_KETO_URL = ENV['ORY_SDK_KETO_URL']
ORY_PROXY_URL = ENV['ORY_PROXY_URL']
ORY_URL = ENV['ORY_URL']
KETO_NAMESPACE = ENV['KETO_NAMESPACE']
ORY_ACCESS_TOKEN = ENV['ORY_ACCESS_TOKEN']
EMAIL_VALIDATION_API_KEY = ENV['EMAIL_VALIDATION_API_KEY']

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  # config.include Devise::Test::ControllerHelpers, type: :controller
  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include Capybara::DSL
  config.include ActiveSupport::Testing::TimeHelpers


  config.before(:suite) do
    DatabaseCleaner.allow_production = true
    DatabaseCleaner.allow_remote_database_url = true
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.after(:each, type: :job) do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.configure_rspec_metadata!
  c.default_cassette_options = {
    :record => :once,
    # :record => :all,
    # :record => :new_episodes, # uncomment during development
  }
  c.ignore_request {|request| request.uri == 'https://recursing-khorana-douoygtthk.projects.oryapis.com/admin/relation-tuples' }
  c.ignore_request {|request| request.uri == 'https://priceless-gould-uo47suopth.projects.oryapis.com/admin/relation-tuples' }

  # Remove any test-specific data
  c.before_record do |i|
    i.response.headers.delete('Set-Cookie')
  end

  c.filter_sensitive_data('TIMIFY_API_KEY') { TIMIFY_API_KEY }
  c.filter_sensitive_data('TIMIFY_API_SECRET') { TIMIFY_API_SECRET }
  c.filter_sensitive_data('TIMIFY_ACCESS_TOKEN') { TIMIFY_ACCESS_TOKEN }
  c.filter_sensitive_data('TIMIFY_APP_ID') { TIMIFY_APP_ID }
  c.filter_sensitive_data('TIMIFY_APP_SECRET') { TIMIFY_APP_SECRET }
  c.filter_sensitive_data('TIMIFY_TEST_COMPANY_ID') { TIMIFY_TEST_COMPANY_ID }

  c.filter_sensitive_data('SS_SCHEDULE_ID') { SS_SCHEDULE_ID }
  c.filter_sensitive_data('SS_CHECKSUM') { SS_CHECKSUM }

  c.filter_sensitive_data('MM_LOGIN') { MM_LOGIN }
  c.filter_sensitive_data('MM_PASSWORD') { MM_PASSWORD }
  c.filter_sensitive_data('MM_KEY') { MM_KEY }

  c.filter_sensitive_data('CRONOFY_CLIENT_SECRET') { CRONOFY_CLIENT_SECRET  }
  c.filter_sensitive_data('CRONOFY_ACCESS_TOKEN') { CRONOFY_ACCESS_TOKEN  }
  c.filter_sensitive_data('CRONOFY_REFRESH_TOKEN') { CRONOFY_REFRESH_TOKEN  }

  c.filter_sensitive_data('MAIL_BCC') { MAIL_BCC }
  c.filter_sensitive_data('HOST') { HOST  }

  c.filter_sensitive_data('ORY_SDK_KETO_URL') { ORY_SDK_KETO_URL  }
  c.filter_sensitive_data('ORY_PROXY_URL') { ORY_PROXY_URL  }
  c.filter_sensitive_data('ORY_URL') { ORY_URL  }
  c.filter_sensitive_data('KETO_NAMESPACE') { KETO_NAMESPACE  }
  c.filter_sensitive_data('ORY_ACCESS_TOKEN') { ORY_ACCESS_TOKEN  }
  c.filter_sensitive_data('EMAIL_VALIDATION_API_KEY') { EMAIL_VALIDATION_API_KEY  }

  c.hook_into :webmock
end