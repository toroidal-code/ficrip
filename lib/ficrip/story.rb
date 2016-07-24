require 'contracts'
require 'open-uri'
require 'retryable'
require 'gepub'

require_relative 'extensions'

module Ficrip
  class Story
    include Contracts::Core
    include Contracts::Builtin

    attr_accessor :title, :author, :url, :metadata

    DOCTYPE = {
        3 => '<!DOCTYPE html>',
        2 => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
    }

    def initialize(title, author, url, metadata = {})
      @title    = title
      @author   = author
      @url      = url
      @metadata = metadata
    end

    def self.construct(title, author, url)
      s = Story::new(title, author, url)
      yield s
      s
    end

    def method_missing(method_sym, *arguments, &block)
      if method_sym != :title= && method_sym != :author= &&
          method_sym.to_s.end_with?('=')
        @metadata.send(:[]=, method_sym[0...-1].to_sym, *arguments, &block)
      elsif @metadata.key?(method_sym) then
        @metadata[method_sym]
      else
        super
      end
    end

    def respond_to_missing?(method_sym, include_private = false)
      @metadata.key?(method_sym) ||
          (method_sym != :title= && method_sym != :author= && method_sym.to_s.end_with?('=')) ||
          super
    end

    Contract Symbol, String => Story

    def add_metadata(key, value)
      @metadata[key] = value
      self
    end

    # Contract { version: Maybe[Or[2, 3]] }
    def bind(version: 3, callback: nil)
      book = GEPUB::Book.new('OEPBS/package.opf', 'version' => version.to_f.to_s)
      book.primary_identifier(@url, 'BookId', 'URL')

      book.language = I18nData.language_code(@metadata[:language]).downcase
      book.title    = @title
      book.creator  = @author

      # Cover if it exists
      if @metadata.key? :cover_url
        cover      = open!(@metadata[:cover_url], 'Referer' => @url)
        cover_type = FastImage.type(cover)
        book.add_item(format('img/cover_image.%s', cover_type), cover)
            .cover_image

        coverpage = <<-XHTML.strip_heredoc
          <?xml version="1.0" encoding="utf-8"?>
          #{DOCTYPE[version]}
          <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
            <head>
              <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
              <title>Cover</title>
              <style type="text/css" title="override_css">
                @page { padding: 0pt; margin:0pt }
                body { text-align: center; padding:0pt; margin: 0pt; }
              </style>
            </head>
            <body>
              <div style="text-align: center;">
                <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1"
                     width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
                  <image width="100%" height="100%" xlink:href="cover_image.#{cover_type}"></image>
                </svg>
              </div>
            </body>
          </html>
        XHTML
      end

      titlepage = <<-XHTML.strip_heredoc
        <?xml version="1.0" encoding="utf-8"?>
        #{DOCTYPE[version]}
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
          <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
            <title>#{@title}</title>
            <style type="text/css" title="override_css">
              .outer { display: table; height: 75%; width: 100%; }
              .middle { display: table-cell; vertical-align: middle; }
              .inner { text-align: center; }
            </style>
          </head>
          <body>
            <div class="outer"><div class="middle"><div class="inner">
              <h1>#{@title}</h1>
              <h3>#{@author}</h3>
            </div></div></div>
          </body>
        </html>
      XHTML


      table_of_contents = nil
      book.ordered do
        book.add_item('img/coverpage.xhtml')
            .add_content(StringIO.new(coverpage))
            .toc_text(@title) if @metadata.key? :cover_url

        book.add_item('text/titlepage.xhtml')
            .add_content(StringIO.new(Nokogiri::XML(titlepage) { |c| c.noblanks }.to_xhtml(indent: 2)))

        book.add_item('text/infopage.xhtml')
            .add_content(StringIO.new(Nokogiri::XML(render_metadata) { |c| c.noblanks }.to_xhtml(indent: 2)))
            .toc_text('About')

        # We want our TOC to be after the cover and titlepage, but we don't any content
        # for it yet, so we save it for later.
        table_of_contents = book.add_item('text/toc.xhtml').toc_text('Table of Contents')

        chapters.each do |chapter|
          chapter_num, chapter_title = chapter.match(/^(\d+)\s*[-\\.)]?\s+(.*)/).captures
          chapter_page               = Nokogiri::HTML open!(URI.join(@url, chapter_num))

          storytext = chapter_page.css('#storytext').first
          storytext.xpath('//@noshade').remove
          storytext.xpath('//@size').remove

          chapter_xhtml = <<-XHTML.strip_heredoc
            <?xml version="1.0" encoding="utf-8"?>
            #{DOCTYPE[version]}
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="en">
              <head>
                <title>c#{chapter_num}</title>
                <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
              </head>
              <body>
                #{'<section epub:type="chapter">' if version == 3}
                  <h1 style="text-align:center">#{chapter_title}</h1>
                  #{storytext.children.to_xhtml}
          #{'</section>' if version == 3}
              </body>
            </html>
          XHTML

          book.add_item(format('text/chapter%03d.xhtml', chapter_num), nil, "c#{chapter_num}")
              .add_content(StringIO.new(Nokogiri::XML(chapter_xhtml) { |c| c.noblanks }.to_xhtml(indent: 2)))
              .toc_text(chapter_title)

          if callback
            args = [chapter_num.to_i, chapters.count]
            n    = callback.arity
            callback.call *(n < 0 ? args : args.take(n))
          end
        end
      end

      # This generates a proper Table of Contents page at the start of the book by
      # removing references to the cover and TOC itself
      book_copy = book.deep_clone
      cut_idx   = @metadata.key?(:cover_url) ? 3 : 2
      book_copy.instance_variable_set(:@toc, book_copy.instance_variable_get(:@toc)[cut_idx..-1])
      table_of_contents.add_content(StringIO.new(book_copy.nav_doc)) # Finally, we get to add the actual content

      # Now that we've generated the TOC page, go through every chapter reference in the
      # toc and prepend the chapter number. This is for the epub's built-in table of contents
      book.instance_variable_get(:@toc)[cut_idx..-1].each_with_index do |chap, idx|
        chap[:text] = "#{idx + 1}. #{chap[:text]}"
      end

      add_item('nav.html', StringIO.new(book_copy.nav_doc), 'nav').add_property('nav') if version == 3

      book
    end

    def render_metadata
      data = {
          'Rating'              => rating,
          'Language'            => language,
          'Genres'              => genres.join(', '),
          'Characters/Pairings' => characters,
          'Chapter count'       => format_num(chapter_count),
          'Word count'          => format_num(word_count),
          'Reviews'             => "<a href='https://fanfiction.com/r/#{info_id}'>" + format_num(review_count) + '</a>',
          'Favorites'           => format_num(favs_count),
          'Follows'             => format_num(follows_count),
          'Updated'             => updated_date,
          'Published'           => published_date,
          'ID'                  => info_id
      }

      Nokogiri::XML::Builder.new(encoding: 'utf-8') { |doc|
        doc.html('xmlns' => 'http://www.w3.org/1999/xhtml', 'xml:lang' => 'en') {
          doc.head {
            doc.meta 'http-equiv' => 'Content-Type', 'content' => 'text/html; charset=UTF-8'
            doc.title 'About'
          }
          doc.body {
            doc.p { doc.strong 'Author: '; doc.a(href: author_url) { doc.text @author } }
            doc.p { doc.strong 'Summary:'; doc.br; doc.text summary }
            data.each do |k, v|
              doc.span {
                doc.strong(k + ':')
                (v.to_s.start_with? '<a') ? doc << v.to_s : doc.text(' ' + v.to_s)
                doc.br
              }
            end
          }
        }
      }.to_xml
    end

    private
    def open!(*args, &block)
      Retryable.retryable(tries: :infinite, on: OpenURI::HTTPError) do
        open(*args, &block)
      end
    end

    def handle_url(string)
      if string.start_with? 'https://www.fanfiction.net/u/'
        "<a href='#{string}'>"
      end
    end

    # # File activesupport/lib/active_support/inflector/methods.rb, line 123
    # def humanize(word, capitalize: false)
    #   result = word.to_s.dup
    #   result.sub!(/\A_+/, ''.freeze)
    #   result.sub!(/_id\z/, ''.freeze)
    #   result.tr!('_'.freeze, ' '.freeze)
    #   result.gsub!(/([a-z\d]*)/i) { |match| match.downcase }
    #   result.sub!(/\A\w/) { |match| match.upcase } if capitalize
    #   result
    # end

    def format_num(num)
      num.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse
    end
  end
end
