# frozen_string_literal: true

module RedmineIssueTemplate
  # What Markdown templates and YAML forms have in common: the name and
  # description shown in the chooser, the title, labels, assignees, type
  # and projects, and Redmine's keys.
  class Template
    attr_reader :path, :name, :about, :title, :labels, :assignees, :type, :projects, :options, :errors

    def initialize(path)
      @path = path
      @errors = []
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
      errors
    end

    # The tracker for the project: `tracker`, then `type`.
    def tracker(project)
      options.tracker_record(project) || find_tracker(project, type)
    end

    # The first entry of `assignees` that can be assigned in the project: a
    # user by login, or a group by name when Redmine allows assigning issues
    # to groups (project.assignable_users has the groups then).
    def assignee(project)
      assignable = project.assignable_users.to_a
      assignees.lazy.map { |entry| find_assignable(assignable, entry) }.find(&:itself)
    end

    # Warnings that depend on the project (names that don't resolve, keys
    # that set nothing in Redmine).
    def project_warnings(project)
      options.resolve(project, path) + key_warnings(project)
    end

    private

    def key_warnings(project)
      warnings = []
      warnings << Message.warning(path, :unknown_type, type: type) if type.present? && find_tracker(project, type).nil?
      warnings << Message.warning(path, :labels_ignored, labels: labels.join(', ')) if labels.any?
      warnings << Message.warning(path, :projects_ignored, projects: projects.join(', ')) if projects.any?
      assignable = project.assignable_users.to_a
      unknown = assignees.reject { |entry| find_assignable(assignable, entry) }
      warnings << Message.warning(path, :assignees_ignored, assignees: unknown.join(', ')) if unknown.any?
      warnings
    end

    def find_assignable(assignable, entry)
      assignable.detect do |principal|
        principal.is_a?(Group) ? principal.name.casecmp?(entry) : principal.login.to_s.casecmp?(entry)
      end
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
      @options = RedmineOptions.parse(path, data, errors)
    end
  end
end
