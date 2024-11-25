class RegistrationsController

  def update
    if params['commit'].eql? "update password"
      @update_password = true
      new_params = {email: account_update_params[:email], password: account_update_params[:password], password_confirmation: account_update_params[:password_confirmation], current_password: account_update_params[:current_password]}
      is_resource_updated?(new_params)
    else
      is_resource_updated?(account_update_params)
    end
  end

  protected
  def update_resource(resource, new_params)
    return super if params['commit'].eql? "update password"
    resource.update_without_password(new_params.except("current_password"))
  end

  def is_resource_updated?(new_params)
      self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
      prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)
      resource_updated = update_resource(resource, new_params)
      yield resource if block_given?
    if resource_updated
      if is_flashing_format?
        flash_key = update_needs_confirmation?(resource, prev_unconfirmed_email) ?
          :update_needs_confirmation : :updated
        set_flash_message :notice, flash_key
      end
      bypass_sign_in resource, scope: resource_name
      respond_with resource, location: after_update_path_for(resource)
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end
end