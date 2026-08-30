module Analyzer
  class Image < Base
    def self.handles?(thing)
      thing.kind == "image"
    end

    def analyze
      with_tempfile do |path|
        step(:dimensions) do
          {
            "width" => run_command("vipsheader", "-f", "width", path).strip.to_i,
            "height" => run_command("vipsheader", "-f", "height", path).strip.to_i
          }
        end

        step(:ocr) { run_command("tesseract", path, "stdout").strip.truncate(MAX_TEXT) }
      end
    end
  end
end
