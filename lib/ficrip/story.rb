require 'contracts'
require 'open-uri'
require_relative 'extensions'

module Ficrip
  class Story
    include Contracts::Core
    include Contracts::Builtin

    attr_accessor :title, :author, :metadata

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
        cover = open(@metadata[:cover_url], 'Referer' => @url)
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

      book.ordered do
        book.add_item('img/coverpage.xhtml')
            .add_content(StringIO.new(coverpage))
            .toc_text(@title) if @metadata.key? :cover_url

        unless @metadata[:chapters]
          @metadata[:chapters] = @url
        end

        chapters.each do |chapter|
          chapter_num, chapter_title = chapter.match(/^(\d+)\s*[-\\.)]?\s+(.*)/).captures
          chapter_page               = Nokogiri::HTML open(URI.join(@url, chapter_num))

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

          book.add_item(format('text/chapter%03d.xhtml', chapter_num),
                        nil, "c#{chapter_num}")
              .add_content(StringIO.new(Nokogiri::XML(chapter_xhtml){|c| c.noblanks}.to_xhtml(indent:2)))
              .toc_text(chapter_title)

          callback.call if callback
        end
      end
      book
    end
  end
end