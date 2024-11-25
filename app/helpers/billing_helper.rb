module BillingHelper
  def billable_minutes(seconds)
    return unless seconds

    (seconds/60.0).ceil
  end

  def min_sec(seconds)
    return unless seconds

    Time.at(seconds).gmtime.strftime("%M Min %S Seconds")
  end
end
