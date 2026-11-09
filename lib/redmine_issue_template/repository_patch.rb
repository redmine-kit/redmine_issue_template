# frozen_string_literal: true

module RedmineIssueTemplate
  # After Redmine fetches the changesets of a project's main repository, the
  # template folder is imported again when it changed.
  module RepositoryPatch
    module_function

    def install
      Redmine::Scm::Base.all.each do |scm|
        klass = "Repository::#{scm}".safe_constantize
        klass&.prepend(FetchChangesets) if klass&.method_defined?(:fetch_changesets)
      end
    end

    module FetchChangesets
      def fetch_changesets(...)
        result = super
        if is_default? && project
          begin
            RepositorySource.sync(project)
          rescue StandardError => e
            Rails.logger.error("redmine_issue_template: sync of #{project.identifier} failed: #{e.class}: #{e.message}")
          end
        end
        result
      end
    end
  end
end
