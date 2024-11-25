class Transfer < TelephonyNode
  def execute
    current_call.update(call_type: 'forwarded', forwarded_at: Time.current)
    to = [users.select{|u| u.available?}.map(&:number), self.to].flatten.compact.uniq.presence
    to ||= [default_user.number] if default_user.available?

    if to&.any?
      from = self.from % data
      telephony.transfer(to, from, self.text)
    else
      puts ">>> ======= no users available directly going to next node: #{next_node.name}"
      next_node.try(:run, @options)
    end
  end
end
