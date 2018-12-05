require 'sinatra'
require 'unirest'
require 'json'
require 'rufus-scheduler'
require 'nokogiri'

SCRAPE_INTERVAL = ENV.fetch("SCRAPE_INTERVAL", "5m")
# FACEBOOK_FUNDRAISER_URL = ENV.fetch("FB_FUNDRAISER_URL", "https://www.facebook.com/donate/517553612043663/")
GOFUNDME_FUNDRAISER_URL = ENV.fetch("GFM_FUNDRAISER_URL", "https://www.gofundme.com/6qvna7-let039s-fund-better-science")
GOFUNDME_FUNDRAISER_URL_2 = ENV.fetch("GFM_FUNDRAISER_URL_2", "https://www.gofundme.com/2qj7u-let039s-fund-better-science")

$urls = [GOFUNDME_FUNDRAISER_URL, GOFUNDME_FUNDRAISER_URL_2]

$adjustment = 0
$facebook = 0
$gofundme = 0

scheduler = Rufus::Scheduler.new

# scheduler.every SCRAPE_INTERVAL do
#   $facebook = Scraper.scrape_facebook(FACEBOOK_FUNDRAISER_URL)
# end

scheduler.every SCRAPE_INTERVAL do
  $gofundme = Scraper.scrape_gofundme(GOFUNDME_FUNDRAISER_URL)
  $gofundme += Scraper.scrape_gofundme(GOFUNDME_FUNDRAISER_URL_2)
end

class DonationTracker < Sinatra::Application
  helpers do
    def protected!
      return if authorized?

      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['admin', ENV.fetch("ADMIN_PASSWORD")]
    end
  end

  get "/" do
    "Hello!"
  end

  get "/total" do
    total = $adjustment + $facebook + $gofundme

    content_type 'text/plain'
    headers 'Access-Control-Allow-Origin' => '*'
    total.to_s
  end

  get "/adjustment" do
    protected!

    """
    <html>
    <body>
    <p>Adjustment is currently $#{$adjustment}.</p>
    <p>Change adjustment by navigating to <pre>/adjustment/NEW-ADJUSTMENT-VALUE</pre>,
    e.g. <pre>/adjustment/950</pre> for a $950 adjustment.</p>
    <p>Scraping every #{SCRAPE_INTERVAL}.</p>
    <p>Scraping these URLs:</p>
    <pre>#{$urls}</pre>
    </body>
    </html>
    """
  end

  get "/adjustment/:value" do
    protected!

    $adjustment = params[:value].to_i
    "Adjustment changed to $#{$adjustment}."
  end
end

class Scraper
  def self.scrape_facebook(url)
    puts "----- Scraping Facebook..."
    Unirest.default_header("User-Agent", "Mozilla/4.0 (compatible; MSIE 6.0)")
    response = Unirest.get(url)
    response = response.body
    response = response.scan(/\$([\d,]+)\SUSD\sof/).last[0]

    # TODO: check that response is a number greater than 100; send an error if not
    response = response.gsub(/[^0-9]/,'').to_i
    puts "     $#{response}"
    response
  end

  def self.scrape_gofundme(url)
    puts "----- Scraping GoFundMe..."
    Unirest.default_header("User-Agent", "Mozilla/4.0 (compatible; MSIE 6.0)")
    response = Unirest.get(url)
    response = response.body

    response = Nokogiri::HTML(response)
    if response.css('h2.goal > span').first.text.strip != "raised"
      puts "      (no money raised)"
      return 0
    end

    response = response.css('h2.goal > strong').first.text
    response = response.delete('£')

    puts "      £#{response}"

    response = response.to_i * 1.3
    response
  end
end
