class SessionsController < ApplicationController

  skip_before_filter :signed_on_to_google

  def new
  end

  def create
    @result = google_api_request('plus', 'v1', 'people', 'get', { userId: auth_info["uid"] } )
    cookies[:access_token] = auth_info["credentials"]["token"]
    cookies[:refresh_token] = auth_info["credentials"]["refresh_token"]

    member = Member.initialize_with_omniauth(auth_info["provider"], auth_info["uid"])
    member.name = @result.data.display_name

    if member.save
      cookies[:remember_token] = member.remember_token
      if session[:return_to]
        redirect_to session[:return_to]
        session.delete(:return_to)
      else
        redirect_to root_path
      end
    else
      redirect_to root_path
    end
  end

  def destroy
    cookies[:remember_token] = nil
    current_member = nil;
    redirect_to "https://accounts.google.com/logout"
  end

end
