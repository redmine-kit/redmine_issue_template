# frozen_string_literal: true

module RedmineIssueTemplate
  # The templates of a project and the chooser's configuration, read from
  # its stored files.
  class TemplateSet
    attr_reader :templates, :config, :messages

    # The parsed files of a project, kept while the stored files are the same.
    def self.for(project)
      files = IssueTemplateFile.where(project_id: project.id).pluck(:path, :content).to_h
      digest = Digest::SHA256.hexdigest(files.sort.to_s)
      @cache ||= {}
      cached = @cache[project.id]
      return cached[1] if cached && cached[0] == digest

      set = Parser.parse(files)
      @cache[project.id] = [digest, set]
      set
    end

    def self.reset!
      @cache = {}
    end

    def initialize(templates:, config:, messages:)
      @templates = templates
      @config = config
      @messages = messages
    end

    # The templates offered in the chooser.
    def usable
      templates.select(&:valid?)
    end

    def find(key)
      usable.detect { |template| template.key == key.to_s }
    end

    def any?
      usable.any?
    end

    def none?
      !any?
    end
  end
end
