require 'contracts'
require 'open-uri'

# Helpers
require 'i18n_data'
require 'fastimage'
require 'chronic_duration'
require 'retryable'

require_relative 'extensions'

module Ficrip
  include Contracts::Core
  include Contracts::Builtin

  Contract Integer => Story
  def self.fetch(storyid)
    base_url     = "https://www.fanfiction.net/s/#{storyid}/"

    primary_page = Retryable.retryable(tries: :infinite, on: OpenURI::HTTPError) do
      Nokogiri::HTML open(base_url)
    end

    raise(ArgumentError.new("Invalid StoryID #{storyid}")) if primary_page.css('#profile_top').count == 0

    title  = primary_page.css('#profile_top > b').first.text
    author = primary_page.css('#profile_top > a').first.text

    Story.construct(title, author, base_url) do |s|
      s.author_url = URI.join(base_url, primary_page.css('#profile_top > a').first['href'])
      s.summary    = primary_page.css('#profile_top > div').text

      info = primary_page.css('#profile_top > span.xgray.xcontrast_txt').text.split(' - ')

      s.rating        = info.find_with 'Rated: Fiction'
      s.language      = info[1]
      s.genres        = info[2].split('/')
      s.characters    = info[3].strip
      s.chapter_count = info.find_with('Chapters:').as { |c| c.parse_int unless c.nil? }
      s.word_count    = info.find_with('Words:').parse_int
      s.review_count  = info.find_with('Reviews:').parse_int
      s.favs_count    = info.find_with('Favs:').parse_int
      s.follows_count = info.find_with('Follows:').parse_int

      s.updated_date = info.find_with('Updated:').as do |d|
        begin
          Date.strptime(d, '%m/%d/%Y')
        rescue
          Date.strptime(d, '%m/%d') rescue (Time.now - ChronicDuration.parse(d)).to_date
        end if d
      end

      s.published_date = info.find_with('Published:').as do |d|
        begin
          Date.strptime(d, '%m/%d/%Y')
        rescue
          Date.strptime(d, '%m/%d') rescue (Time.now - ChronicDuration.parse(d)).to_date
        end
      end

      s.info_id = info.find_with('id:').to_i

      raise(Exception.new("Error! StoryID and parsed ID don't match.")) if s.info_id != storyid

      cover_elem     = primary_page.css('img.lazy.cimage').first
      s.cover_url    = URI.join(base_url, cover_elem['data-original']) if cover_elem

      # Get the contents of the first chapter selector at the top of the page
      chapter_select = primary_page.css('select#chap_select').first
      if chapter_select
        s.chapters = chapter_select.children.map(&:text)
      else
        s.chapters = ["1. #{title}"]
      end
    end
  end

  Contract Integer => GEPUB::Book
  def self.get(storyid, version: 3)
    fetch(storyid).bind(version: version)
  end

end
