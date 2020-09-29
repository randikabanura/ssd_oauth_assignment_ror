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

        @my_liked_videos = client.list_videos('snippet,contentDetails,statistics', my_rating: 'like').items
        @my_disliked_videos = client.list_videos('snippet,contentDetails,statistics', my_rating: 'dislike').items
      rescue => e
        sign_out(current_user)
      end
    end
  end

  def terms
  end

  def privacy
  end

  def remove_subscription
    redirect_to root_path unless current_user.present?

    channel_id = params[:id]
    client = get_youtube_client current_user

    begin
      client.delete_subscription(channel_id)
      flash[:success] = 'Subscription deletion was successful'
      redirect_to root_path
    rescue => e
      flash[:error] = 'Subscription deletion was unsuccessful'
      redirect_to root_path
    end
  end

  def video_search
    if request.post?
      video_url = params[:youtube_video][:youtube_url]
      video_id = get_youtube_id(video_url)

      redirect_to video_search_view_path(video_id: video_id)
    else
      video_id = params[:video_id]

      client = get_youtube_client current_user
      @video = client.list_videos('contentDetails, snippet, statistics, status', id: video_id).items.first
    end
  end

  private

  def get_youtube_id(youtube_url)
    regex = /(?:youtube(?:-nocookie)?\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/
    match = regex.match(youtube_url)
    if match && !match[1].blank?
      match[1]
    else
      nil
    end
  end

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
