class RenewConversationJob < ApplicationJob
  queue_as :default

  def perform(*args)
    conversations = Conversation.where("client_id IS NOT NULL AND ivr_id IS NOT NULL AND expire_at IS NULL AND created_at < ?", 1.days.ago)

    conversations.each do |conversation|
      conversation.update_columns(expire_at: Time.current)
      newConversation = Conversation.create(client_id: conversation.client_id, ivr_id: conversation.ivr_id, from: conversation.from, to: conversation.to, session_id: conversation.session_id)
      conversation.text_messages.update_all(conversation_id: newConversation.id)
    end

  rescue Exception => e
    logger.error "XXXXXX Exception while renew conversations"
    puts e.message
  end
end
