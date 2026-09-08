module Analyzer
  class Media < Base
    SAMPLE_RATE = "16000".freeze
    CHANNELS = "1".freeze
    DEFAULT_SPAN = 3600
    DEFAULT_BINARY = "whisper-cli".freeze
    STREAMS = 8

    def self.handles?(feed)
      MimeType.audio?(feed.mime) || MimeType.video?(feed.mime)
    end

    def self.model
      ENV["URIS_WHISPER_MODEL"].presence
    end

    def self.binary
      ENV.fetch("URIS_WHISPER_BIN", DEFAULT_BINARY)
    end

    def self.span
      ENV.fetch("URIS_TRANSCRIBE_SECONDS", DEFAULT_SPAN).to_i
    end

    def analyze
      with_tempfile do |path|
        step(:probe) { probe(path) }
        step(:transcript) { transcribe(path) }
      end
    end

    def file_facts
      [ super, duration_said, streams_said ].compact_blank.join("\n")
    end

    def summary_body
      fenced(step_result(:transcript).to_s.strip)
    end

    SAYS = <<~SAYS.strip.freeze
      two or three sentences on what is said and who says it. Name the people,
          places, products and dates spoken rather than their category. Where nothing
          was transcribed, say what the recording appears to be from its name and
          length, and say plainly that nothing was heard.
    SAYS

    def summary_noun
      "recording"
    end

    def summary_says
      SAYS
    end

    private

      def probe(path)
        parsed = JSON.parse(
          run_command("ffprobe", "-v", "error", "-print_format", "json",
                      "-show_format", "-show_streams", path)
        )

        {
          "format" => parsed.dig("format", "format_name"),
          "duration" => parsed.dig("format", "duration")&.to_f&.round(2),
          "bit_rate" => parsed.dig("format", "bit_rate")&.to_i,
          "title" => parsed.dig("format", "tags", "title"),
          "streams" => Array(parsed["streams"]).first(STREAMS).map { |stream| described(stream) }
        }.compact
      rescue JSON::ParserError
        raise Analyzer::Failed, "ffprobe did not describe #{reference.filename}"
      end

      def described(stream)
        {
          "type" => stream["codec_type"],
          "codec" => stream["codec_name"],
          "width" => stream["width"],
          "height" => stream["height"],
          "channels" => stream["channels"],
          "sample_rate" => stream["sample_rate"]&.to_i,
          "language" => stream.dig("tags", "language")
        }.compact
      end

      def transcribe(path)
        model = self.class.model

        if model.blank?
          raise Analyzer::Failed,
                "no transcription model is configured — set URIS_WHISPER_MODEL to a ggml model file"
        end

        unless File.file?(model)
          raise Analyzer::Failed, "URIS_WHISPER_MODEL names #{model}, which is not a file"
        end

        raise Analyzer::Failed, "#{reference.filename} carries no audio" unless audio?

        Dir.mktmpdir do |dir|
          heard = File.join(dir, "heard.wav")

          run_command("ffmpeg", "-v", "error", "-y", "-i", path, "-vn",
                      "-t", self.class.span.to_s, "-ac", CHANNELS, "-ar", SAMPLE_RATE,
                      "-f", "wav", heard)

          spoken(run_command(self.class.binary, "-m", model, "-f", heard, "-nt", "-np"))
        end
      end

      def spoken(output)
        output.to_s.lines.map(&:strip).reject(&:empty?).join("\n").truncate(MAX_TEXT)
      end

      def audio?
        streams.any? { |stream| stream["type"] == "audio" }
      end

      def streams
        Array(step_result(:probe).to_h["streams"])
      end

      def duration
        step_result(:probe).to_h["duration"].to_f
      end

      def duration_said
        return nil unless duration.positive?

        "Length: #{ActiveSupport::Duration.build(duration.round).inspect}"
      end

      def streams_said
        described = streams.filter_map do |stream|
          case stream["type"]
          when "video" then "video #{stream['codec']} #{stream['width']}×#{stream['height']}"
          when "audio" then "audio #{stream['codec']} #{stream['channels']}ch"
          end
        end

        "Streams: #{described.join(', ')}" if described.any?
      end
  end
end
