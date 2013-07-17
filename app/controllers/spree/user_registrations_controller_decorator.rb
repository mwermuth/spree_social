Spree::UserRegistrationsController.class_eval do

  after_filter :clear_omniauth, :only => :create

  private

  def build_resource(*args)
    super
    Rails.logger.info(args)
    Rails.logger.info(@user)
    Rails.logger.info(@spree_user)
    if @user != nil
      if session[:omniauth]
        @user.apply_omniauth(session[:omniauth])
      end
      @user 
    else
      if session[:omniauth]
        @spree_user.apply_omniauth(session[:omniauth])
      end
      @spree_user 
    end
  end

  def clear_omniauth
    session[:omniauth] = nil unless @user.new_record?
  end
end
