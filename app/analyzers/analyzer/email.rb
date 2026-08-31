require "mail"

module Analyzer
  class Email < Base
    HEADERS = %w[from to cc subject date message_id].freeze

    def self.handles?(thing)
      thing.kind == "email"
    end

    # An attachment is a thing of its own, so it is catalogued as one before
    # the message is read: `children_of` hands the bytes up and the base class
    # writes them, keyed and idempotently, into this tenant's own storage. The
    # message still records what it named, because the names are worth
    # searching even when the bytes are not there.
    def has_children?
      true
    end

    def children_of(reference)
      Mail.read_from_string(reference.download.read.force_encoding("UTF-8").scrub)
          .attachments
          .filter_map do |attachment|
            next if attachment.filename.blank?

            { filename: attachment.filename, body: attachment.body.decoded }
          end
    rescue StandardError
      []
    end

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
