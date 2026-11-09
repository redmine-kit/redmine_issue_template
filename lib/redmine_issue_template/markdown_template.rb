# frozen_string_literal: true

module RedmineIssueTemplate
  # What Markdown templates and issue forms have in common: the name and
  # description shown in the chooser, the title, GitHub's labels, assignees,
  # type and projects, and the `redmine` options.
  class Template
    attr_reader :path, :name, :about, :title, :labels, :assignees, :type, :projects, :options, :errors, :warnings

    def initialize(path)
      @path = path
      @errors = []
      @warnings = []
      @labels = []
      @assignees = []
      @projects = []
      @options = RedmineOptions.new({})
    end

    # The template's id in URLs: the file name without its extension.
    def key
      File.basename(path).sub(/\.(md|ya?ml)\z/, '')
    end

    def valid?
      errors.empty?
    end

    def form?
      false
    end

    def messages
      errors + warnings
    end

    # The tracker for the project: `redmine.tracker`, then GitHub's `type`,
    # then the first label that names a tracker.
    def tracker(project)
      options.tracker_record(project) ||
        find_tracker(project, type) ||
        labels.lazy.map { |label| find_tracker(project, label) }.find(&:itself)
    end

    # The first assignee who can be assigned in the project.
    def assignee(project)
      assignable = project.assignable_users.to_a
      assignees.lazy.map { |login| assignable.detect { |user| user.respond_to?(:login) && user.login.casecmp?(login) } }
               .find(&:itself)
    end

    # Warnings that depend on the project (names that don't resolve, GitHub
    # keys without a Redmine equivalent).
    def project_warnings(project)
      options.resolve(project, path) + github_key_warnings(project)
    end

    private

    def github_key_warnings(project)
      warnings = []
      warnings << Message.warning(path, :unknown_type, type: type) if type.present? && find_tracker(project, type).nil?
      unmatched = labels.reject { |label| find_tracker(project, label) }
      warnings << Message.warning(path, :labels_ignored, labels: unmatched.join(', ')) if unmatched.any?
      warnings << Message.warning(path, :projects_ignored, projects: projects.join(', ')) if projects.any?
      unknown = unknown_assignees(project)
      warnings << Message.warning(path, :assignees_ignored, assignees: unknown.join(', ')) if unknown.any?
      warnings
    end

    def unknown_assignees(project)
      logins = project.assignable_users.select { |user| user.respond_to?(:login) }.map { |user| user.login.downcase }
      assignees.reject { |login| logins.include?(login.downcase) }
    end

    def find_tracker(project, name)
      return nil if name.blank?

      project.trackers.detect { |tracker| tracker.name.casecmp?(name.to_s) }
    end

    def read_common(data, about_key)
      @name = data['name'].to_s.strip.presence
      @about = data[about_key].to_s.strip.presence
      @title = data['title'].to_s.presence
      @labels = Parser.list(data['labels'])
      @assignees = Parser.list(data['assignees'])
      @projects = Parser.list(data['projects'])
      @type = data['type'].to_s.strip.presence
      @options = RedmineOptions.parse(path, data['redmine'], errors, warnings)
    end
  end

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
