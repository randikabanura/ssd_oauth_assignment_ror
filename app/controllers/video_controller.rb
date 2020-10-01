require "google/apis/youtube_v3"
require "google/api_client/client_secrets.rb"

class VideoController < ApplicationController
  before_action :authenticate_user!

  def liked_videos
    if current_user.present?
      client = get_youtube_client current_user
      @my_liked_videos = []

      liked_videos_call = client.list_videos('snippet,contentDetails,statistics', my_rating: 'like')

      while liked_videos_call&.next_page_token.present?
        @my_liked_videos << liked_videos_call.items
        liked_videos_call = client.list_videos('snippet,contentDetails,statistics', my_rating: 'like', page_token: liked_videos_call&.next_page_token)
      end
      @my_liked_videos.flatten!

      if @my_liked_videos.blank?
        flash[:error] = 'You does not have any liked videos'
        redirect_to root_path
      end
    else
      redirect_to root_path
    end
  end

  def my_subscriptions
    client = get_youtube_client current_user
    @my_subscriptions = []

    subscription_call = client.list_subscriptions('snippet,contentDetails', mine: true)
    while subscription_call&.next_page_token.present?
      @my_subscriptions << subscription_call.items
      subscription_call = client.list_subscriptions('snippet,contentDetails', mine: true, page_token: subscription_call&.next_page_token)
    end
    @my_subscriptions.flatten!
    channel_ids = @subscription_list.map(&:snippet).map(&:resource_id).map(&:channel_id)
    @channels_list = client.list_channels('snippet, statistics', id: channel_ids).items

    if @my_subscriptions.blank?
      flash[:error] = 'You does not have any subscriptions'
      redirect_to root_path
    end
  end

  def disliked_videos
    if current_user.present?
      client = get_youtube_client current_user
      @my_disliked_videos = []

      disliked_videos_call = client.list_videos('snippet,contentDetails,statistics', my_rating: 'dislike')
      while disliked_videos_call&.next_page_token.present?
        @my_disliked_videos << disliked_videos_call.items
        disliked_videos_call = client.list_videos('snippet,contentDetails,statistics', my_rating: 'like', page_token: disliked_videos_call&.next_page_token)
      end
      @my_disliked_videos.flatten!

      if @my_disliked_videos.blank?
        flash[:error] = 'You does not have any disliked videos'
        redirect_to root_path
      end
    else
      redirect_to root_path
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
