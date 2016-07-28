
require_relative '../application'     # explizites require erforderlich bei Nutzung als Engine in anderer App

Rails.application.configure do
  # Log error messages when you accidentally call methods on nil.
  #config.whiny_nils = true              # deprecated 21.07.13 Ramm

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Do not compress assets
  config.assets.compress = false

  # Use a different cache store in production
  #config.cache_store = :mem_cache_store
  config.cache_store = :memory_store


  ############# Neue Rails 4 Settings
   # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  # Auskommentiert wegen Abhängigkeit zu ActionMailer, Ramm, 28.07.2016
  #config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  # Migration nicht prüfen, Ramm 28.07.2016
  # config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
end



