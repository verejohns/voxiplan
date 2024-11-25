# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

Rails.application.config.after_initialize do
  Rails.application.config.assets.precompile.delete(/\.(?:svg|eot|woff|woff2|ttf)$/)
end

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
=begin
Rails.application.config.assets.paths << Rails.root.join('app', 'assets', 'fonts')

Rails.application.config.assets.precompile += %w(
  application.js
  application-v2.js
  application-v3.js
  plugins/plugins.bundle.js
  plugins/draggable/draggable.bundle.js
  plugins/fullcalendar/fullcalendar.bundle.js
  plugins/tinymce/tinymce.bundle.js
  plugins/tinymce/langs/en.js
  plugins/tinymce/langs/fr.js
  plugins/tinymce/langs/de.js
  plugins/tinymce/langs/it.js
  plugins/tinymce/langs/el.js
  plugins/sms-counter/sms-counter.bundle.js
  plugins/formrepeater/formrepeater.bundle.js
  plugins/three-states-switch-jtoggler/jtoggler.js
  countrySelect.min.js
  intlTelInput.min.js
  jquery.form.min.js
  utils.js
  basic.js
  cable.js
  chosen.jquery.min.js
  datatables.bundle.js
  moment-locales.js
  select2.js
  onboarding.js
  calendar.js
  availablities.js
  pricing.js
  air-datepicker-3.0.1.js

  application-v2.css
  application-v3.css
  plugins/plugins.bundle.css
  plugins/fullcalendar/fullcalendar.bundle.css
  plugins/three-states-switch-jtoggler/jtoggler.styles.css
  intlTelInput.min.css
  countrySelect.min.css
  chosen.css
  datatables.bundle.css
  metronic.css
  select2.min.css
  font-awesome.min.css
  line-awesome.min.css
  air-datepicker.css
)
=end