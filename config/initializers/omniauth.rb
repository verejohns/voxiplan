Rails.application.config.middleware.use OmniAuth::Builder do

  provider :cronofy, ENV["CRONOFY_US_CLIENT_ID"], ENV["CRONOFY_US_CLIENT_SECRET"], {
      scope: "read_account list_calendars create_calendar read_events create_event delete_event read_free_busy",
      provider_ignores_state: true
  }

  provider :cronofy, ENV["CRONOFY_SG_CLIENT_ID"], ENV["CRONOFY_SG_CLIENT_SECRET"], {
    scope: "read_account list_calendars create_calendar read_events create_event delete_event read_free_busy",
    provider_ignores_state: true
  }

  provider :cronofy, ENV["CRONOFY_UK_CLIENT_ID"], ENV["CRONOFY_UK_CLIENT_SECRET"], {
    scope: "read_account list_calendars create_calendar read_events create_event delete_event read_free_busy",
    provider_ignores_state: true
  }

  provider :cronofy, ENV["CRONOFY_DE_CLIENT_ID"], ENV["CRONOFY_DE_CLIENT_SECRET"], {
    scope: "read_account list_calendars create_calendar read_events create_event delete_event read_free_busy",
    provider_ignores_state: true
  }

  provider :cronofy, ENV["CRONOFY_AU_CLIENT_ID"], ENV["CRONOFY_AU_CLIENT_SECRET"], {
    scope: "read_account list_calendars create_calendar read_events create_event delete_event read_free_busy",
    provider_ignores_state: true
  }

  provider :cronofy, ENV["CRONOFY_CA_CLIENT_ID"], ENV["CRONOFY_CA_CLIENT_SECRET"], {
    scope: "read_account list_calendars create_calendar read_events create_event delete_event read_free_busy",
    provider_ignores_state: true
  }

end