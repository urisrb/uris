require "roo"

module Analyzer
  class Xlsx < Base
    SAMPLE_ROWS = 20
    MAX_COLUMNS = 30
    CELL = 200

    def self.handles?(thing)
      thing.kind == "xlsx"
    end

    # A sheet is the page here: headers plus a sample of rows is what makes a
    # spreadsheet findable, and rendering one adds nothing a search index can use.
    def analyze
      sheets = step(:sheets) { with_workbook { |workbook| shape_of(workbook) } }

      step(:text) { flatten(sheets).truncate(MAX_TEXT) }
    end

    private

      def with_workbook
        with_tempfile { |path| yield Roo::Spreadsheet.open(path) }
      rescue Roo::Error, ArgumentError, Zip::Error => e
        raise Analyzer::Failed, "unreadable spreadsheet: #{e.message.truncate(200)}"
      end

      def shape_of(workbook)
        workbook.sheets.map do |name|
          sheet = workbook.sheet(name)
          first = sheet.first_row || 1
          last = sheet.last_row || 0
          columns = [ sheet.last_column || 0, MAX_COLUMNS ].min

          {
            "name" => name,
            "rows" => last,
            "columns" => sheet.last_column || 0,
            "headers" => cells(sheet, first, columns),
            "sample" => ((first + 1)..[ last, first + SAMPLE_ROWS ].min).map { |row| cells(sheet, row, columns) },
            "truncated" => last > first + SAMPLE_ROWS
          }
        end
      end

      def cells(sheet, row, columns)
        (1..columns).map do |column|
          value = sheet.cell(row, column)
          value.is_a?(String) ? value.truncate(CELL) : value
        end
      end

      def flatten(sheets)
        sheets.map do |sheet|
          rows = [ sheet["headers"], *sheet["sample"] ]

          ([ sheet["name"] ] + rows.map { |row| row.compact.join(" | ") }).join("\n")
        end.join("\n\n")
      end
  end
end
