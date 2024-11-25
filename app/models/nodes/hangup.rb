class Hangup < TelephonyNode
  def execute
    current_call.update_column(:finished_at, Time.current)
    telephony.hangup
  end
end