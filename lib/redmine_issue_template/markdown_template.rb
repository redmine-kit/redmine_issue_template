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
      match = FRONT_MATTER.match(content)
      if match.nil?
        errors << Message.error(path, :no_front_matter)
        return
      end
      @body = content[match.end(0)..].to_s.sub(/\A\s*\n/, '')
      data = Parser.load_yaml(path, match[1], errors)
      return if data.nil?

      unless data.is_a?(Hash)
        errors << Message.error(path, :front_matter_not_map)
        return
      end
      read_common(data, 'about')
      errors << Message.error(path, :missing_key, key: 'name') if name.nil?
      errors << Message.error(path, :missing_key, key: 'about') if about.nil?
    end
  end
end
