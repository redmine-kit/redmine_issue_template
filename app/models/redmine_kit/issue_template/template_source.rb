# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # Where a project's template files come from (repository, github or
    # manual), the revision, time and digest of the last import, and the
    # projects its templates are shared with (sharing: Redmine's 「共有」 of a
    # version, RedmineKit::Subprojects::Sharing).
    class TemplateSource < ApplicationRecord
      self.table_name = 'redmine_kit_issue_template_sources'

      SHARINGS = RedmineKit::Subprojects::Sharing::VALUES

      belongs_to :project

      validates :kind, inclusion: { in: SOURCES }
      validates :sharing, inclusion: { in: SHARINGS }

      def self.for(project)
        find_or_initialize_by(project_id: project.id)
      end

      # The one place for the project whose templates a project uses: its own
      # when it has files; else, as GitHub uses an organization's templates
      # for a repository without its own, the nearest project that shares its
      # templates with it (as Redmine shares a version: Sharing.available_to,
      # archived projects never) and has files and the module on: an ancestor
      # (the closest first), then the others of the tree in Redmine's order.
      # Without one, the project itself (no templates).
      def self.provider_for(project)
        return project if project.new_record? || TemplateFile.exists?(project_id: project.id)

        shared = RedmineKit::Subprojects::Sharing.available_to(where.not(project_id: project.id), project)
                                                 .where(project_id: TemplateFile.select(:project_id))
                                                 .where(project_id: EnabledModule.where(name: 'issue_templates')
                                                                                 .select(:project_id))
        projects = Project.where(id: shared.select(:project_id)).to_a
        projects.max_by { |p| [p.is_ancestor_of?(project) ? 1 : 0, p.is_ancestor_of?(project) ? p.lft : -p.lft] } ||
          project
      end

      # The sharings the user may choose, as Version#allowed_sharings
      # (hierarchy and tree with manage_issue_templates in the root project,
      # すべてのプロジェクト for system administrators).
      def allowed_sharings(user = User.current)
        RedmineKit::Subprojects::Sharing.allowed(SHARINGS, sharing_in_database || 'none', project, user,
                                                 :manage_issue_templates)
      end

      # Saves the sharing when it is one the user may choose; another value or
      # shape is refused (Redmine's "is not included in the list"), and
      # nothing is saved. One change at a time per project, as the files'.
      def share(value, user = User.current)
        TemplateFile.transaction do
          project.lock!
          unless value.is_a?(String) && allowed_sharings(user).include?(value)
            errors.add(:sharing, :inclusion)
            next false
          end
          self.sharing = value
          save
        end
      end

      # The errors and warnings of the project's files, from the stored files:
      # the files' own, and those that depend on the project (names it doesn't
      # have).
      def self.messages_for(project)
        set = TemplateSet.own(project)
        set.messages + set.usable.flat_map { |template| template.project_warnings(project) }
      end

      # Files from the repository or GitHub are edited there, not in Redmine.
      def manual?
        kind == 'manual'
      end
    end
  end
end
