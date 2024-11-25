module AgendaConnectHelper
  def get_data_center(client)
    data_center = 'us' #app.cronofy.com'
    data_center = 'de' if client.server_region == 'EU'  # app-de.cronofy.com
    data_center = 'sg' if client.time_zone[0..3] == 'Asia'    # app-sg.cronofy.com
    data_center = 'uk' if client.country_code == 'GB'         # app-uk.cronofy.com
    data_center = 'au' if client.country_code == 'AU'         # app-au.cronofy.com
    data_center = 'ca' if client.country_code == 'CA'         # app-ca.cronofy.com
    data_center
  end

  def get_api_center_url(data_center)
    data_center_url = 'https://api.cronofy.com'
    data_center_url = 'https://api-de.cronofy.com' if data_center.downcase == 'de'  # app-de.cronofy.com
    data_center_url = 'https://api-sg.cronofy.com' if data_center.downcase == 'sg'  # app-sg.cronofy.com
    data_center_url = 'https://api-uk.cronofy.com' if data_center.downcase == 'uk'  # app-uk.cronofy.com
    data_center_url = 'https://api-au.cronofy.com' if data_center.downcase == 'au'  # app-au.cronofy.com
    data_center_url = 'https://api-ca.cronofy.com' if data_center.downcase == 'ca'  # app-ca.cronofy.com
    data_center_url
  end

end
