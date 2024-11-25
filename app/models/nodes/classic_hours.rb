class ClassicHours < Node

  def self.filter_params params_busiess_hour
  	business_hours = {}
    business_days = params_busiess_hour.keys
    business_days.each do |bday|
      if params_busiess_hour[bday][:on]=='true'
        business_hours[bday] = []
        params_busiess_hour[bday][:before_break]["from"] =  params_busiess_hour[bday][:before_break]["from"].to_time.strftime("%H:%M")
        params_busiess_hour[bday][:before_break]["to"] =  params_busiess_hour[bday][:before_break]["to"].to_time.strftime("%H:%M")
        business_hours[bday].push(params_busiess_hour[bday][:before_break].as_json)
        if params_busiess_hour[bday][:break]=='true'
          params_busiess_hour[bday][:after_break]["from"] =  params_busiess_hour[bday][:after_break]["from"].to_time.strftime("%H:%M")
          params_busiess_hour[bday][:after_break]["to"] =  params_busiess_hour[bday][:after_break]["to"].to_time.strftime("%H:%M")
          business_hours[bday].push(params_busiess_hour[bday][:after_break].as_json)
        end
      end
    end
    return business_hours
  end

end