# frozen_string_literal: true

module RedmineIssueTemplate
  # The templates of a project and the chooser's configuration, read from
  # its stored files.
  class TemplateSet
    attr_reader :templates, :config, :messages

    # The parsed files of a project, kept while the stored files are the same
    # (their number, last change and last id, without reading the contents).
    def self.for(project)
      scope = IssueTemplateFile.where(project_id: project.id)
      key = scope.pick(Arel.sql('COUNT(*)'), Arel.sql('MAX(updated_at)'), Arel.sql('MAX(id)'))
      @cache ||= {}
      cached = @cache[project.id]
      return cached[1] if cached && cached[0] == key

      set = Parser.parse(scope.pluck(:path, :content).to_h)
      @cache[project.id] = [key, set]
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

    # The templates the user can create issues with in the project: those
    # whose tracker the user may use, and those that set none.
    def usable_for(project, user = User.current)
      trackers = Issue.new(project: project).allowed_target_trackers(user)
      usable.select { |template| (tracker = template.tracker(project)).nil? || trackers.include?(tracker) }
    end

    def any?
      usable.any?
    end
  end
end
