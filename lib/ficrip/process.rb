# frozen_string_literal: true
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

  Contract Or[Nat,String] => Story
  def self.fetch(storyid_or_url)
    find_by_slice = lambda do |ary, str|
      r = ary.find { |i| i.start_with? str }
      r.gsub(str, '').strip if r
    end

    process_num = lambda do |str|
      str.try_this do |count|
        Integer(count.delete(',.'))
      end.result
    end

    storyid = begin
      storyid_or_url =~ Regexp.new('fanfiction.net/s/(\d+)', true)
      Integer ($1 || storyid_or_url)
    rescue
      raise ArgumentError.new("\"#{storyid_or_url}\" is not a fanfiction.net URL or a StoryID")
    end

    base_url = "https://www.fanfiction.net/s/#{storyid}/"

    primary_page = Retryable.retryable(tries: :infinite, on: OpenURI::HTTPError) do
      Nokogiri::HTML open(base_url)
    end

    if primary_page.css('#profile_top').count == 0
      raise(ArgumentError.new("Invalid StoryID #{storyid}"))
    end

    title  = primary_page.css('#profile_top > b').first.text
    author = primary_page.css('#profile_top > a').first.text

    Story.construct(title, author, base_url) do |s|
      s.author_url = URI.join(base_url, primary_page.css('#profile_top > a').first['href'])
      s.summary    = primary_page.css('#profile_top > div').text

      info = primary_page.css('#profile_top > span.xgray.xcontrast_txt').text.split(' - ')

      s.rating        = find_by_slice.(info, 'Rated: Fiction')
      s.language      = info[1]
      s.genres        = info[2].split('/')
      s.characters    = info[3].strip
      s.chapter_count = process_num.call find_by_slice.(info, 'Chapters:')
      s.word_count    = process_num.call find_by_slice.(info, 'Words:')
      s.review_count  = process_num.call find_by_slice.(info, 'Reviews:')
      s.favs_count    = process_num.call find_by_slice.(info, 'Favs:')
      s.follows_count = process_num.call find_by_slice.(info, 'Follows:')

      s.updated_date =
          find_by_slice.(info,'Updated:')
              .try_this { |d| Date.strptime(d, '%m/%d/%Y') }
              .and_this { |d| Date.strptime(d, '%m/%d') }
              .and_this { |d| (Time.now - ChronicDuration.parse(d)).to_date }
              .result

      s.published_date =
          find_by_slice.(info,'Published:')
              .try_this { |d| Date.strptime(d, '%m/%d/%Y') }
              .and_this { |d| Date.strptime(d, '%m/%d') }
              .and_this { |d| (Time.now - ChronicDuration.parse(d)).to_date }
              .result

      s.info_id = find_by_slice.(info,'id:').to_i

      raise Exception.new("Error! StoryID and parsed ID don't match.") if s.info_id != storyid

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

  Contract Or[Nat,String] => GEPUB::Book
  def self.get(storyid_or_url, version: 3)
    fetch(storyid_or_url).bind(version: version)
  end
end
