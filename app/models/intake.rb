class Intake
  class Unusable < StandardError; end

  MAX_KEY = 900
  MAX_NAME = 180

  Landed = Data.define(:feed, :reference, :analysis)

  class << self
    def write!(path:, body:, mime: nil, title: nil, source: nil, cause: "upload")
      destination = Resource.default_storage

      raise Unusable, "no default storage is set — pick one on Resources" if destination.nil?

      key = key_for(path)
      locator = destination.storage!.upload(key, body)
      locator = locator.merge("source_url" => source.to_s) if source.present?

      reference = Reference.discover!(
        resource: destination,
        locator: locator,
        locator_key: key,
        mime: mime.presence || MimeType.for_filename(key),
        title: title.presence || File.basename(key)
      )

      Landed.new(
        feed: reference.feed,
        reference: reference,
        analysis: reference.feed.analyze!(cause: cause)
      )
    end

    def key_for(given)
      segments = given.to_s.tr("\\", "/").split("/").filter_map do |segment|
        cleaned = segment.gsub(/[[:cntrl:]]/, "").strip
        cleaned unless cleaned.empty? || cleaned == "." || cleaned == ".."
      end

      raise Unusable, "#{given} is not a usable path" if segments.empty?

      key = segments.join("/")

      raise Unusable, "that path is too long" if key.bytesize > MAX_KEY

      key
    end

    def filed(prefix, name, at: Time.current)
      "#{prefix}/#{at.utc.strftime('%Y%m%dT%H%M%S')}-#{named(name)}"
    end

    def named(given, fallback: "untitled")
      readable = given.to_s.dup.force_encoding(Encoding::UTF_8).scrub
      base = File.basename(readable.tr("\\", "/")).gsub(/[[:cntrl:]]/, "").strip
      extension = File.extname(base)
      stem = base.delete_suffix(extension).parameterize.presence || fallback

      "#{stem.first(MAX_NAME)}#{extension.downcase.first(16)}"
    end
  end
end
