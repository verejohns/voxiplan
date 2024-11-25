class RecordName < Record
  def handle_response
    data[self.name.to_sym] = current_recording.voxi_url #if response[:upload_status] == 'success'
    update_url
    puts "********* recorded saved at #{data[self.name.to_sym]}"
    next_node.run(@options)
  end
end