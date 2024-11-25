Shortener::ShortenedUrlsController.class_eval do

  def show
    puts 'Shortener::ShortenedUrlsController-------------------------------'
    begin
	  token = ::Shortener::ShortenedUrl.extract_token(params[:id])
	  track = Shortener.ignore_robots.blank? || request.human?
	  url  = ::Shortener::ShortenedUrl.fetch_with_token(token: token, additional_params: params, track: track)
	  shortened_url =  url[:shortened_url] if url[:shortened_url].present?
	  shortened_url.analytics.create(click_time: Time.now) if shortened_url
      redirect_to url[:url], status: :moved_permanently
    rescue => e
      puts e.message
    end
  end
end
