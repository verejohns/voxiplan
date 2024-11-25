require 'capybara/poltergeist'

# Configure Poltergeist to not blow up on websites with js errors aka every website with js
# See more options at https://github.com/teampoltergeist/poltergeist#customization
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, js_errors: false)
end

# Configure Capybara to use Poltergeist as the driver
Capybara.default_driver = :poltergeist

class SuperSaasSignUpJob < ApplicationJob
  queue_as :default

  def perform(client_id)

    client = Client.find client_id
    client.agenda_sign_up_fields['ss_password'] = SecureRandom.hex(3)
    browser = Capybara.current_session
    browser.visit('https://agenda.voxiplan.com/dashboard/login')

    browser.fill_in('name', with: ENV['SS_ACCOUNT'])
    browser.fill_in('password', with: ENV['SS_PASSWORD'])
    browser.click_on('Log In')

    browser.visit "https://agenda.voxiplan.com/accounts/new_client"

    browser.fill_in('account_name', with: client.agenda_sign_up_fields['ss_account'])
    browser.fill_in('account_password', with: client.agenda_sign_up_fields['ss_password'])
    browser.fill_in('account_email', with: client.email)
    browser.fill_in('account_full_name', with: client.full_name)


    country = ISO3166::Country[client.country].name
    browser.find('#account_country').click.first(:option, country).select_option

    browser.click_on('Create Account')

    if browser.has_text?('Account successfully created')
      puts "************* create new client on SuperSaas: success"
      client.agenda_sign_up_fields['success'] = true
      client.agenda_sign_up_fields['errors'] = {}
      ClientNotifierMailer.agenda_account_created(client).deliver_later
    elsif browser.has_text?('Account Name has already been registered')
      puts "************* create new client on SuperSaas: Already registered"
      client.agenda_sign_up_fields.delete('success')
      client.agenda_sign_up_fields['errors'] = {'ss_account' => 'Account Name has already been registered'}
    end

    client.save
    Rails.logger.info " ********* SuperSaas script complteted ******** "
    browser.save_and_open_page
  rescue Exception => error
    logger.info " ********* Exception while creating Super Saas sign-up JOB ******** #{error.inspect} "
  end
end
