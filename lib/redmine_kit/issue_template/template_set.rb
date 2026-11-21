# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # The templates of a project and the chooser's configuration, read from
    # its stored files.
    class TemplateSet
      attr_reader :templates, :config, :messages

      # The parsed sets of the projects, in every thread of the process, up to
      # this size (the least recently used go first). Stored as they are
      # (coder: nil), not copied on each read: a set is frozen, all of it,
      # before it is stored, so that no request changes what another reads.
      CACHE = ActiveSupport::Cache::MemoryStore.new(size: 32.megabytes, coder: nil)

      # The parsed files of a project, kept while the stored files are the same
      # (their number, last change and last id, without reading the contents).
      def self.for(project)
        scope = IssueTemplateFile.where(project_id: project.id)
        count, updated, last = scope.pick(Arel.sql('COUNT(*)'), Arel.sql('MAX(updated_at)'), Arel.sql('MAX(id)'))
        # the time with its fractions of a second (Time#to_param drops them)
        updated = updated.iso8601(6) if updated.respond_to?(:iso8601)
        CACHE.fetch([project.id, count, updated, last].join('/')) do
          files = scope.pluck(:path, :content, :too_long).to_h do |path, content, too_long|
            [path, too_long ? Parser::TOO_LONG : content]
          end
          Ractor.make_shareable(Parser.parse(files))
        end
      end

      def self.reset!
        CACHE.clear
      end

      # Whether the user may create an issue without a template in the
      # project: where the module is off, and as #blank_issue_allowed? says.
      def self.blank_issue_allowed?(project, user = User.current)
        return true unless project.module_enabled?(:issue_templates)

        self.for(project).blank_issue_allowed?(project, user)
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

      # A blank issue (no template): allowed by config.yml
      # (blank_issues_enabled), to those who manage the templates, and where
      # the user may use none of the templates. The chooser, the new UI's
      # step and the refusal of issues without a template all ask this.
      def blank_issue_allowed?(project, user = User.current)
        config.blank_issues_enabled? || user.allowed_to?(:manage_issue_templates, project) ||
          usable_for(project, user).none?
      end
    end
  end
end
