source 'https://rubygems.org'
ruby '~> 2.7.6'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# To load environment variables from .env into ENV in development
gem 'dotenv-rails'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'

gem 'rails', '~> 5.2.8.1'

gem 'bootsnap', '~> 1.15.0', require: false

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.4.5'
# Use Puma as the app server
gem 'puma', '~> 6.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 6.0', '>= 6.0.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 5.0.0'
gem 'rack-cors', require: 'rack/cors'

gem 'clipboard-rails'
# TODO: remove if not needed
gem 'listen', '~> 3.7.1'

# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

gem 'country_select', '~> 8.0.0'

gem 'countries', '~> 5.2.0'

gem 'money'

gem 'money-uphold-bank'

gem 'google-cloud-text_to_speech', '~> 1.3.0'

gem 'i18n-tasks', '~> 1.0.12'

# Spam protection solution for Rails applications.
gem 'invisible_captcha'

gem 'deepl-rb', '~> 2.5.3', require: 'deepl'

gem 'easy_translate'

# gem 'timify_ruby', github: 'teknuk/timify_ruby'
# gem 'timify_ruby', git: "https://github.com/aboven/timify_ruby.git"
# gem 'timify_ruby', git: "https://github.com/axonymous/timify_ruby.git"

gem 'timify_ruby', git: "https://github.com/aboven/timify_ruby.git", branch: 'new-api'

gem 'twilio-ruby', '~> 5.73.4'

gem 'cronofy'
gem 'omniauth-cronofy'

# background jobs
# TODO: remove if not used
gem 'sucker_punch', '~> 3.1.0'

# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.5.1'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# TODO: remove because not used
gem 'jbuilder', '~> 2.11.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# A Ruby library for interaction with the Tropo Web API using JSON.
gem 'tropo-webapi-ruby'
gem 'ssmd'

# To make API calls to SuperSAAS
gem 'httparty'

gem 'bootstrap-generators', '~> 3.3.4'

# # Phone number validation gem based on Google's libphonenumber library.
# gem 'telephone_number'
gem 'phonelib', '~> 0.7.5'
gem 'paper_trail', '~> 13.0.0'
gem 'paper_trail-association_tracking'
gem 'paper_trail-globalid'
# localization
gem 'rails-i18n', '~> 5.1.3' # For 5.2.5
gem 'http_accept_language'

# searching and filtering
# gem 'ransack'

gem 'capybara', '~> 3.38.0'
gem 'poltergeist'

# TODO: remove?
gem 'paperclip'
gem 'aws-sdk', '~> 3'

gem 'biz'
# time Picker
gem 'bootstrap-timepicker-rails'
gem 'bootstrap-datepicker-rails'

gem 'skylight', '~> 5.3.4'
gem 'jwt'
gem 'octobat'
gem 'sendgrid-ruby'

gem 'rollbar'

gem 'google-cloud-speech', '~> 1.4.0'

gem 'shortener', '~> 1.0.0'

# Run rake tasks as migrations for Ruby on Rails
gem 'rake-task-migration'

# gem 'carrierwave'
# gem "fog-aws"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug', '~> 3.10.1', platform: :mri
  gem 'rspec-rails', '~> 5.1'
  gem 'vcr'
  gem 'webmock', '~> 3.18.1'
  # gem 'selenium-webdriver'
  gem 'awesome_print'
  gem 'rails-controller-testing'
  gem 'rspec_junit_formatter', '~> 0.6.0'
end

group :test do
  gem 'database_cleaner'
  gem 'rubocop', '~> 1.40.0'
  gem 'simplecov', require: false, group: :test
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 3.7.0'

  # when upgrading to Rails 6
  # gem 'spring', '~> 4.1.0'
  # gem 'spring-watcher-listen', '~> 2.1.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring', '~> 2.1.1'
  gem 'spring-watcher-listen', '~> 2.0.1'

  # To preview emails in development (to remove, not used)
  # gem "letter_opener"
end

# Google Tag Manager
gem 'gtm_rails'

# Sendgrid Template integration
gem 'smtpapi'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem 'bootstrap-growl-rails'
gem 'activerecord-session_store'
gem "rolify"
gem 'jquery-datatables-rails', github: 'rweng/jquery-datatables-rails'
gem "roo", "~> 2.9.0"
gem "nested_form"
gem "percentage"
gem 'sprockets', '~> 4.1.1'
gem 'tzinfo', '>= 1.2.10'

# Chargebee

gem 'chargebee', '~> 2.21.0'

gem 'language_list'

# gem 'ory-kratos-client', '~> 0.10.1'

gem 'ory-client', '~> 1.1.0'

gem 'barnes'

gem 'dalli'

gem 'nokogiri', '~> 1.13.10'

#gem 'newrelic_rpm'