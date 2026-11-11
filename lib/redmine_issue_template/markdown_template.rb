# frozen_string_literal: true

module RedmineIssueTemplate
  # A Markdown issue template: YAML front matter and the issue body.
  class MarkdownTemplate < Template
    FRONT_MATTER = /\A---[ \t]*\r?\n(.*?)^---[ \t]*\r?\n?/m

    attr_reader :body

    def self.parse(path, content)
      template = new(path)
      template.read(content.to_s)
      template
    end

    def read(content)
      data = front_matter(content)
      return if data.nil?

      read_common(data, 'about')
      %w[name about].each { |key| errors << Message.error(path, :missing_key, key: key) if public_send(key).nil? }
    end

    private

    # The front matter as a hash, with the body after it; nil after an error.
    def front_matter(content)
      match = FRONT_MATTER.match(content)
      if match.nil?
        errors << Message.error(path, :no_front_matter)
        return nil
      end

      @body = content[match.end(0)..].to_s.sub(/\A\s*\n/, '')
      data = Parser.load_yaml(path, match[1], errors)
      return data if data.nil? || data.is_a?(Hash)

      errors << Message.error(path, :front_matter_not_map)
      nil
    end
  end
end
