module NavigationHelper
  MenuItem = Struct.new(:label, :path, :icon, :children)

  extend ActiveSupport::Concern
  include Rails.application.routes.url_helpers

  included do
    def default_url_options
      ActionMailer::Base.default_url_options
    end
  end

  # dashboard: "Dashboard"
  # activity: "Insights"
  # interact: "Campaigns"
  # configure: "Settings"
  # integrations: "Integrations"
  def main_areas_with_paths
    [
      [ t('nav_menu.services'), :services],
      # [ t('nav_menu.dashboard'), :dashboard],
      # [ t('nav_menu.activity'),  :activity],
      # [ t('nav_menu.settings'),  :configure],
      # [ t('nav_menu.integrations'), :integrations]
    ]
  end

  def header_menu_items
    {
      services: [MenuItem.new(t('nav_menu.services'), root_path, 'flaticon-dashboard')],
      activity: common_activity,
      configure: [],
      integrations: [
        MenuItem.new(
          t('nav_menu.partner_agenda'), select_agenda_integrations_path, 'flaticon2-calendar-8',
          [
            MenuItem.new('', services_path),
            MenuItem.new('', connect_your_agenda_integrations_path),
            MenuItem.new('', overview_integrations_path)
          ]
        ),
        MenuItem.new(
        t('nav_menu.communication_channels'), phone_integrations_path, 'flaticon2-talk',
          [
            MenuItem.new(t('nav_menu.phone_numbers'), phone_integrations_path),
            MenuItem.new(t('nav_menu.sms'), sms_integrations_path)
          ]
        ),
        MenuItem.new(t('nav_menu.tracking_analytics'), tracking_integrations_path, 'flaticon-analytics'),
        MenuItem.new(t('nav_menu.chat'), chat_index_path(current_ivr.booking_url), 'flaticon-speech-bubble'),
        MenuItem.new(t('nav_menu.notify'), sms_path, 'flaticon-alert')
      ],
      settings: common_account_nav_link,
      demo: common_account_nav_link,
    }
  end

  def common_activity
    common_activity_nest = []
      common_activity_nest << MenuItem.new(t('nav_menu.calls'), calls_reports_path) if current_menu == 'Phone'
      common_activity_nest << MenuItem.new(t('nav_menu.sms'), sms_reports_path)
      common_activity_nest << MenuItem.new(t('nav_menu.clicks'), url_reports_path)
      common_activity_nest << MenuItem.new(t('nav_menu.chat'), chat_index_path(current_ivr.booking_url), 'flaticon-speech-bubble') if request.host.include? "dev"
    common_activity_nest
  end

  def common_account_nav_link
    [
      MenuItem.new(t('nav_menu.my_account'), edit_client_registration_path, 'flaticon2-user'),
      MenuItem.new(t('nav_menu.my_team'), user_page_settings_path, 'flaticon2-group'),
      MenuItem.new(t('nav_menu.billing'), root_path, 'flaticon-business'),
    ]
  end

  def main_areas
    main_areas_with_paths.map do |group|
      group[0]
    end
  end

  def main_menu_items
    main_areas_with_paths.map do |group|
      MenuItem.new(group[0].to_s.titlecase, group[1], group[2])
    end
  end

  def breadcrumb_path
    {
      "activity" => t('nav_menu.activity'),
      "my-assistant" => t('breadcrumb.my_assistant'),
      "interact" => t('nav_menu.interact'),
      "settings" => t('nav_menu.configure'),
      "integrations" => t('nav_menu.integrations')
    }
  end

  def breadcrumb_map
    {
      "activity" => ['calls','sms_list','url','customers'],
      "my-assistant" => [],
      "interact" => [],
      "settings" => ['announce','language','business_hours','greetings','phone_menu','follow_up','local_service_and_resource','preference','service_and_resource','custom_texts','notification','reminders'],
      "integrations" => ['connect_your_agenda','phone','sms','tracking','sms_campaign']
    }
  end

  def current_header_area_label
    # breadcrumb_path.each do |key, value|
    #   if key === current_main_area.to_s
    #     return value
    #   end
    # end
    breadcrumb_map.each do |key, value|
      if value.include? current_path.split('/').last
        return breadcrumb_path.assoc(key)&.last
      end
    end
    return ""
  end

  def current_header_menu_items (main_area)
    header_menu_items.fetch(main_area, [])
  end

  def current_main_area
    current_path.split('/')[1].to_s.to_sym
  end

  def active_class(item)
    # binding.pry
    return if current_path == "/#{current_main_area}"
    if item.path.include?(current_path)
      'kt-menu__item--here'
    elsif item.children && item.children.any?{|c| c.path.include?(current_path)}
      'kt-menu__item--here'
    end
  end

  def childrens_with_label?(item)
    item.children.map(&:label).reject { |e| e.to_s.empty? }.present?
  end

  def active_menu_item(item)
    # return if current_path == "/#{current_main_area}"
    'kt-menu__item--active' if (current_path.count("/") > 1) && item.path.include?(current_path)
  end
end
