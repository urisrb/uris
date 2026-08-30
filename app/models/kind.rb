module Kind
  BY_EXTENSION = {
    "pdf" => "pdf",
    "png" => "image", "jpg" => "image", "jpeg" => "image", "gif" => "image",
    "webp" => "image", "heic" => "image", "tif" => "image", "tiff" => "image",
    "txt" => "text", "md" => "text", "rtf" => "text",
    "csv" => "data", "tsv" => "data", "json" => "data", "xml" => "data",
    "xlsx" => "xlsx", "xls" => "xlsx", "ods" => "xlsx",
    "doc" => "doc", "docx" => "doc", "odt" => "doc",
    "ics" => "calendar",
    "vcf" => "contact", "vcard" => "contact",
    "pkpass" => "pkpass",
    "eml" => "email"
  }.freeze

  DEFAULT = "file"

  def self.for_filename(name)
    BY_EXTENSION.fetch(File.extname(name.to_s).delete(".").downcase, DEFAULT)
  end
end
