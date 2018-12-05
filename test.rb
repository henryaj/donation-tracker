require_relative './app'

p Scraper.scrape_facebook(FACEBOOK_FUNDRAISER_URL)

puts ""

p Scraper.scrape_gofundme(GOFUNDME_FUNDRAISER_URL)

puts ""

p Scraper.scrape_gofundme(GOFUNDME_FUNDRAISER_URL_2)
