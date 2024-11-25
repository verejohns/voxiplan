class VoxiSMSEngin < TelephonyEngine
  def send_sms(sms_id)
    VoxiSMSJob.perform_later(sms_id)
  end
end