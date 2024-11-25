class AddColumnShortUrlToShortenedUrls < ActiveRecord::Migration[5.0]
  def change
    add_column :shortened_urls, :short_url, :string
  end
end
