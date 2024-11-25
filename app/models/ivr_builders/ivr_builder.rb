class IvrBuilder
  attr_accessor :options

  def initialize(ivr, options={})
    @ivr = ivr
    @options = options || {}
  end

  def prefix
    @options[:prefix]
  end

  def ext_options
    {ext_prefix: prefix, ext_title: @options[:title], ext_action: ext_action}
  end

  def name(name)
    prefix ? "#{prefix}_#{name}" : name
  end

  def create(type, name, options)
    if @options[:copy_text]
      old_node = @ivr.find_node("#{name}__old")
      if old_node
        options[:text] = old_node.text if options[:text].class == old_node.text.class
        options[:enabled] = old_node.enabled
        if old_node.users.present?
          options[:users] = old_node.users
        end
      end
    end

    @ivr.nodes.create({type: type, name: name}.merge(options))
  end

  def by_preference?
    @options[:scheduling_method] == 'by_preference'
  end

  def default_users
    [@ivr.default_user]
  end

  delegate :t, to: :I18n

  def confirmation_node_text(time = 'choosen_slot_start' )
    {
        explicit: {
            text: t('static_ivr.appointment_cofirmation'),
            condition: "%{ ivr_preference_implicit_confirmation == false }"
        },
        implicit: {
            text: t('static_ivr.appointment_cofirmation_implicit', time: time),
            condition: "%{ivr_preference_implicit_confirmation == true }"
        }
    }
  end

  def self.confirmation_nodes
    %w[confirm_create confirm_cancel]
  end


  # AppointmentBot.new(ivr).send(:change_bot_type, :ai)
  # type => :ai or :static
  def change_bot_type(type)
    nodes = @ivr.nodes.where name: %w[appointment_announcement_open appointment_announcement_closed]
    if type == :ai
      # @ivr.preference['service_or_resource_start'] = nodes.first.next
      # @ivr.save
      nodes.update_all(next: 'ai_bot_start_conversation')
    else
      nodes.update_all(next: 'get_existing_appointments')
    end
  end
end