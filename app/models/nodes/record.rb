class Record < Node
  def execute
    if @options.delete(:parse_response)
      handle_response
    else
      telephony.record(interpolated_text, url)
    end
  end

  def current_recording
    @current_recording ||= current_call.recordings.find_or_create_by(node_name: self.name, file_name: file_name)
  end

  def handle_response
    # data[self.name.to_sym] = response[:url] if response[:upload_status] == 'success'
    data[self.name.to_sym] = current_recording.voxi_url #if response[:upload_status] == 'success'
    update_url
    puts "********* recorded saved at #{data[self.name.to_sym]}"
    next_node.run(@options)
  end

  def file_name
    parameters.try(:[], :'file_name') || self.name
  end

  def url
    call_id = data[:tropo_call_id]
    "/webhooks/recording?uuid=#{current_recording.uuid}"
    # "https://#{ENV['AWS_REGION']}.amazonaws.com/#{ENV['S3_BUCKET_NAME']}/#{file_name}_#{call_id}.wav"
  end

  private

  def update_url
    response = telephony.get_response
    return unless response[:url].present?
    current_recording.update_attributes(url: response[:url])
  end
end