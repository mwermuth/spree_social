class Spree::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Spree::Core::ControllerHelpers::Common
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Auth

  def self.provides_callback_for(*providers)
    providers.each do |provider|
      class_eval %Q{
        def #{provider}
          if request.env["omniauth.error"].present?
            flash[:error] = t("devise.omniauth_callbacks.failure", :kind => auth_hash['provider'], :reason => t(:user_was_not_valid))
            redirect_back_or_default(root_url)
            return
          end

          authentication = Spree::UserAuthentication.find_by_provider_and_uid(auth_hash['provider'], auth_hash['uid'])
          key = auth_hash['provider']+"_token"
          session[:instagram_token] = auth_hash['credentials']['token']
          
          if authentication.present? && spree_current_user == nil
            flash[:notice] = "Signed in successfully"
            sign_in_and_redirect :spree_user, authentication.user
          elsif spree_current_user && authentication.present?
            if authentication.user.email != spree_current_user.email
              flash[:notice] = "Account already linked."
              session[:instagram_token] = nil
              redirect_back_or_default(account_url)
            else
              spree_current_user.apply_omniauth(auth_hash)
              spree_current_user.save!
              flash[:notice] = "Authentication successful."
              redirect_back_or_default(account_url)
            end
          elsif spree_current_user
            spree_current_user.apply_omniauth(auth_hash)
            spree_current_user.save!
            flash[:notice] = "Authentication successful."
            redirect_back_or_default(account_url)
          else
            user = Spree::User.find_by_nickname(auth_hash['info']['nickname']) || Spree::User.new
            user.apply_omniauth(auth_hash)
            if user.save
              flash[:notice] = "Signed in successfully."
              sign_in_and_redirect :spree_user, user
            else
              session[:omniauth] = auth_hash.except('extra')
              flash[:notice] = t(:one_more_step, :kind => auth_hash['provider'].capitalize)
              user.mark_as_confirmed()
              redirect_to complete_path(:spree_user => user)
            end
          end

          if current_order
            user = spree_current_user || authentication.user
            current_order.associate_user!(user)
            session[:guest_token] = nil
          end
        end
      }
    end
  end

  SpreeSocial::OAUTH_PROVIDERS.each do |provider|
    provides_callback_for provider[1].to_sym
  end

  def failure
    set_flash_message :alert, :failure, :kind => failed_strategy.name.to_s.humanize, :reason => failure_message
    redirect_to spree.login_path
  end

  def passthru
    render :file => "#{Rails.root}/public/404", :formats => [:html], :status => 404, :layout => false
  end

  def auth_hash
    request.env["omniauth.auth"]
  end
end
