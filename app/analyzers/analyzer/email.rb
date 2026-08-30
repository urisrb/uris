require "mail"

module Analyzer
  class Email < Base
    HEADERS = %w[from to cc subject date message_id].freeze

    def self.handles?(thing)
      thing.kind == "email"
    end

    # An .eml is headers plus parts. The attachments are named but not pulled
    # out: an attachment is a thing of its own, and making one here would mean
    # writing bytes from inside an analyzer, which is the sync path's job.
    def analyze
      message = parse

      step(:headers) { headers_of(message) }
      step(:attachments) { attachments_of(message) }
      step(:text) { body_of(message).truncate(MAX_TEXT) }
    end

    private

      def parse
        Mail.read_from_string(reference.download.read.force_encoding("UTF-8").scrub)
      rescue StandardError => e
        raise Analyzer::Failed, "unreadable message: #{e.message.truncate(200)}"
      end

      def headers_of(message)
        HEADERS.index_with { |name| stringify(message.public_send(name)) }.compact
      end

      def stringify(value)
        case value
        when nil then nil
        when Array then value.join(", ").presence
        else value.to_s.presence
        end
      end

      def attachments_of(message)
        message.attachments.map do |attachment|
          {
            "filename" => attachment.filename,
            "content_type" => attachment.mime_type,
            "size" => attachment.body.decoded.bytesize
          }
        end
      rescue StandardError
        []
      end

      # Prefer the plain part; fall back to stripping the html one, because a
      # message with only an html body is common and its text is still the
      # thing worth searching.
      def body_of(message)
        part = message.multipart? ? (message.text_part || message.html_part) : message

        text = part&.decoded.to_s.force_encoding("UTF-8").scrub
        text = strip_tags(text) if part&.mime_type == "text/html"

        [ stringify(message.subject), text ].compact.join("\n\n").strip
      rescue StandardError
        stringify(message.subject).to_s
      end

      def strip_tags(html)
        html.gsub(%r{<(script|style)[^>]*>.*?</\1>}mi, " ")
            .gsub(/<[^>]+>/, " ")
            .gsub(/&nbsp;/i, " ")
            .squeeze(" ")
            .strip
      end
  end
end
