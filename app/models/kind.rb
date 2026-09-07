module Kind
  RAW = %w[
    3fr ari arw cap cr2 cr3 crw dcr dng erf fff iiq k25 kdc mdc mos mrw
    nef nrw orf ori pef pxn raf rw2 rwl sr2 srf srw x3f
  ].freeze

  BY_EXTENSION = {
    "pdf" => "pdf",
    "png" => "image", "jpg" => "image", "jpeg" => "image", "gif" => "image",
    "webp" => "image", "heic" => "image", "tif" => "image", "tiff" => "image",
    "bmp" => "image", "ico" => "image",
    "txt" => "text", "md" => "text", "rtf" => "text", "markdown" => "text",
    "rb" => "text", "rake" => "text", "gemspec" => "text", "py" => "text",
    "js" => "text", "mjs" => "text", "cjs" => "text", "jsx" => "text",
    "ts" => "text", "tsx" => "text", "go" => "text", "rs" => "text",
    "java" => "text", "kt" => "text", "swift" => "text", "php" => "text",
    "c" => "text", "h" => "text", "cc" => "text", "cpp" => "text", "hpp" => "text",
    "cs" => "text", "sh" => "text", "bash" => "text", "zsh" => "text", "fish" => "text",
    "sql" => "text", "yml" => "text", "yaml" => "text", "toml" => "text", "ini" => "text",
    "cfg" => "text", "conf" => "text", "env" => "text", "html" => "text", "erb" => "text",
    "css" => "text", "scss" => "text", "sass" => "text", "less" => "text",
    "lock" => "text", "mdx" => "text", "graphql" => "text", "proto" => "text",
    "csv" => "data", "tsv" => "data", "json" => "data", "xml" => "data",
    "xlsx" => "xlsx", "xls" => "xlsx", "ods" => "xlsx",
    "doc" => "doc", "docx" => "doc", "odt" => "doc",
    "mp3" => "audio", "m4a" => "audio", "wav" => "audio", "flac" => "audio",
    "ogg" => "audio", "oga" => "audio", "opus" => "audio", "aac" => "audio",
    "wma" => "audio", "aiff" => "audio", "aif" => "audio", "m4b" => "audio",
    "mp4" => "video", "m4v" => "video", "mov" => "video", "mkv" => "video",
    "webm" => "video", "avi" => "video", "wmv" => "video", "mpg" => "video",
    "mpeg" => "video",
    "ics" => "calendar",
    "vcf" => "contact", "vcard" => "contact",
    "pkpass" => "pkpass",
    "eml" => "email"
  }.merge(RAW.index_with("image")).freeze

  DEFAULT = "file"

  def self.for_filename(name)
    BY_EXTENSION.fetch(extension(name), DEFAULT)
  end

  def self.raw?(name)
    RAW.include?(extension(name))
  end

  def self.extension(name)
    File.extname(name.to_s).delete(".").downcase
  end
end
