require "google/apis/youtube_v3"
require "google/api_client/client_secrets.rb"

class HomeController < ApplicationController
  def index
    if current_user.present?
      client = get_youtube_client current_user
      @next_page_token = params[:next_page_token]
      @prev_page_token = params[:prev_page_token]
      @subscription_list = []

      begin
        if @next_page_token.blank? && @prev_page_token.blank?
          subscription_call = client.list_subscriptions('snippet, contentDetails', mine: true)
          @subscription_list += subscription_call.items
        elsif @next_page_token.present?
          subscription_call = client.list_subscriptions('snippet, contentDetails', mine: true, page_token: @next_page_token)
          @subscription_list += subscription_call.items
        elsif @prev_page_token.present?
          subscription_call = client.list_subscriptions('snippet, contentDetails', mine: true, page_token: @prev_page_token)
          @subscription_list += subscription_call.items
        end

        @prev_page_token = subscription_call&.prev_page_token
        @next_page_token = subscription_call&.next_page_token

        channel_ids = @subscription_list.map(&:snippet).map(&:resource_id).map(&:channel_id)
        @channels_list = client.list_channels('snippet, statistics', id: channel_ids).items
      rescue => e
        sign_out(current_user)
      end
    end
  end

  def terms
  end

  def privacy
  end

  private

  def get_youtube_client(current_user)
    client = Google::Apis::YoutubeV3::YouTubeService.new
    return unless (current_user.present? && current_user.services.last.access_token.present? && current_user.services.last.refresh_token.present?)
    secrets = Google::APIClient::ClientSecrets.new({
                                                       "web" => {
                                                           "access_token" => current_user.services.last.access_token,
                                                           "refresh_token" => current_user.services.last.refresh_token,
                                                           "client_id" => Rails.application.credentials[Rails.env.to_sym][:google_oauth2][:app_id],
                                                           "client_secret" => Rails.application.credentials[Rails.env.to_sym][:google_oauth2][:app_secret]
                                                       }
                                                   })
    begin
      client.authorization = secrets.to_authorization
      client.authorization.grant_type = "refresh_token"
      if !current_user.present?
        client.authorization.refresh!
        current_user.services.last.update_attributes(
            access_token: client.authorization.access_token,
            refresh_token: client.authorization.refresh_token,
            expires_at: client.authorization.expires_at.to_i
        )
      end
    rescue => e
      flash[:error] = 'Your token has been expired. Please login again with google.'
      redirect_to :back
    end
    client
  end
end
