class TrackingURL < Node
  KEY_MAPING = {client_name: :client_first_name, caller_id: :caller_id, appointment_start_time: :choosen_slot_start, chosen_service: :choosen_service, chosen_resource: :choosen_resource, customer_name: :customer_first_name}
  def execute
    puts 'TrackingURL-----------------------------------'
    begin
      if self.enabled
        keys = interpolated_keys(self.text)
        puts "URL: #{self.text}-------------------------------------"
        puts "keys in URL: #{keys}-------------------------------------"
        unless keys.blank?
          keys = [keys] if keys.class == Symbol
          non_keys = keys - KEY_MAPING.keys
          keys = keys - non_keys
          puts "keys from System: #{keys}-------------------------------------"
          selected_keys = (KEY_MAPING.select {|key, value| keys.include?(key) }).values
          new_data = dup_data.slice(*selected_keys)

          new_data.merge!({choosen_service: (Service.find_by(eid: new_data[:choosen_service]) || Service.find_by(id: new_data[:choosen_service])).name })
          new_data.merge!({choosen_resource: (Resource.find_by(eid: new_data[:choosen_resource]) || Resource.find_by(id: new_data[:choosen_resource])).name })


          original_key_data= new_data.map {|key, value| [KEY_MAPING.key(key), value]}.to_h
          url = self.text % original_key_data
        else
          url = self.text
        end

        HTTParty.get(url) unless url.blank?
        puts "hit url: #{url}-------------------------------------"
      end
    rescue => e
      puts "Error: #{e.message}-----------------------------------"
    end
    next_node.try(:run, @options)
  end
end