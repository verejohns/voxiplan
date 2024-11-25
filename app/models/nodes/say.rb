class Say < TelephonyNode

  def execute
    telephony.say(interpolated_text)
  end
end