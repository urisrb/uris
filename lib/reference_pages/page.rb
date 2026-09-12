module ReferencePages
  class Page
    def self.write(root = Rails.root.join("docs/src/content/docs/reference"))
      page = new
      path = root.join("#{page.slug}.mdx")

      FileUtils.mkdir_p(path.dirname)
      File.open(path, "w") { |file| file.puts(page.render.rstrip) }
      path
    end

    def render
      [ frontmatter, *body ].join("\n")
    end

    private

      def frontmatter
        <<~HEAD
          ---
          title: #{title}
          description: #{description}
          ---

          #{intro.strip}

          Generated from the code by `./dev reference`. CI fails when this page and the code disagree.
        HEAD
      end

      def table(headings, rows)
        return "None.\n" if rows.empty?

        [
          "| #{headings.join(' | ')} |",
          "| #{headings.map { '---' }.join(' | ')} |",
          *rows.map { |row| "| #{row.map { |cell| escaped(cell) }.join(' | ')} |" },
          ""
        ].join("\n")
      end

      def escaped(cell)
        cell.to_s.gsub("|", "\\|").gsub("\n", " ").gsub("<", "&lt;").gsub("{", "&#123;")
      end

      def code(value)
        "`#{value}`"
      end

      def prose(text)
        text.to_s.squish
      end
  end
end
