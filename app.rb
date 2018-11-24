require 'sinatra'
require 'unirest'
require 'json'
require 'rufus-scheduler'

SCRAPE_INTERVAL = ENV.fetch("SCRAPE_INTERVAL", "5m")

scheduler = Rufus::Scheduler.new

scheduler.every SCRAPE_INTERVAL do
  DonationTracker.scrape_facebook
  DonationTracker.scrape_gofundme
end

class DonationTracker < Sinatra::Application
  @@facebook_fundraiser_url = "https://www.facebook.com/donate/517553612043663/"
  @@gofundme_fundraiser_url = "https://www.gofundme.com/6qvna7-let039s-fund-better-science"

  @@adjustment = 0

  helpers do
    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['admin', ENV.fetch("ADMIN_PASSWORD")]
    end
  end

  get "/" do
    "Hello!"
  end

  get "/total" do
    total = facebook + gofundme + adjustment

    content_type 'text/plain'
    headers 'Access-Control-Allow-Origin' => '*'
    total.to_s
  end

  get "/adjustment" do
    protected!

    """
    <html>
    <body>
    <p>Adjustment is currently $#{adjustment}.</p>
    <p>Change adjustment by navigating to <pre>/adjustment/NEW-ADJUSTMENT-VALUE</pre>,
    e.g. <pre>/adjustment/950</pre> for a $950 adjustment.</p>
    <p>Scraping #{@@facebook_fundraiser_url} and #{@@gofundme_fundraiser_url} every #{SCRAPE_INTERVAL}.</p>
    </body>
    </html>
    """
  end

  get "/adjustment/:value" do
    protected!

    @@adjustment = params[:value].to_i
    "Adjustment changed to $#{@@adjustment}."
  end

  def facebook
    @@facebook ||= DonationTracker.scrape_facebook
  end

  def gofundme
    @@gofundme ||= DonationTracker.scrape_gofundme
  end

  def adjustment
    @@adjustment
  end

  def self.scrape_facebook
    puts "Scraping Facebook..."
    Unirest.default_header("User-Agent", "Mozilla/4.0 (compatible; MSIE 6.0)")
    response = Unirest.get(@@facebook_fundraiser_url)
    response = response.body
    response = response.split('<span class="_1r05">$')
    response = response[1]
    response = response.split('USD of')
    response = response[0]

    # TODO: check that response is a number greater than 100; send an error if not
    response.gsub(/[^0-9]/, '')
    @@facebook = response.to_i
  end

  def self.scrape_gofundme
    puts "Scraping GoFundMe..."
    Unirest.default_header("User-Agent", "Mozilla/4.0 (compatible; MSIE 6.0)")
    response = Unirest.get(@@gofundme_fundraiser_url)
    response = response.body
    response = response.gsub(/\r|\n/, '')

    response = response.split('<strong>£')
    response = response[1]

    response = response.split('</strong>')
    response = response[0]

    response = response.to_i * 1.3
    @@gofundme = response
  end
end
