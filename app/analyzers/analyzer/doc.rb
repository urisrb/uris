module Analyzer
  class Doc < Base
    def self.handles?(thing)
      thing.kind == "doc"
    end

    # LibreOffice is the only thing that reads .docx and .odt faithfully, so a
    # doc becomes a PDF first and then takes the PDF pipeline. Each conversion
    # gets its own profile directory: soffice takes a lock on a shared one, and
    # two analysis jobs would otherwise serialize on it or fail outright.
    def analyze
      as_pdf do |pdf|
        step(:info) { Pdf.parse_info(run_command("pdfinfo", pdf)) }
        step(:text) { run_command("pdftotext", "-q", pdf, "-").strip.truncate(MAX_TEXT) }
      end
    end

    private

      def as_pdf
        with_tempfile do |source|
          Dir.mktmpdir do |dir|
            run_command("soffice", "-env:UserInstallation=file://#{File.join(dir, 'profile')}",
                        "--headless", "--convert-to", "pdf", "--outdir", dir, source)

            pdf = Dir[File.join(dir, "*.pdf")].first
            raise Analyzer::Failed, "libreoffice produced no pdf" if pdf.nil?

            yield pdf
          end
        end
      end
  end
end
