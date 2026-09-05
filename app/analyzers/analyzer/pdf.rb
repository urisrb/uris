module Analyzer
  class Pdf < Base
    def self.handles?(item)
      item.kind == "pdf"
    end

    def self.parse_info(output)
      output.lines.each_with_object({}) do |line, info|
        field, value = line.split(":", 2)
        next if value.nil?

        info[field.strip.downcase.tr(" ", "_")] = value.strip
      end.slice("pages", "title", "author", "creationdate", "page_size")
    end

    def analyze
      with_tempfile do |path|
        step(:info) { Pdf.parse_info(run_command("pdfinfo", path)) }
        step(:text) { run_command("pdftotext", "-q", path, "-").strip.truncate(MAX_TEXT) }
      end
    end
  end
end
