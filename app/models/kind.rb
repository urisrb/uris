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
    "txt" => "text", "md" => "text", "rtf" => "text",
    "csv" => "data", "tsv" => "data", "json" => "data", "xml" => "data",
    "xlsx" => "xlsx", "xls" => "xlsx", "ods" => "xlsx",
    "doc" => "doc", "docx" => "doc", "odt" => "doc",
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
