# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # After Redmine fetches the changesets of a project's main repository, the
    # template folder is imported again when the fetch added changesets.
    # RepositoriesController#show fetches on each view when "Fetch commits
    # automatically" is on, so a fetch that adds nothing reads nothing; the
    # settings' "Import" reads the folder at any time.
    module RepositoryPatch
      module_function

      def install
        Redmine::Scm::Base.all.each do |scm|
          klass = "Repository::#{scm}".safe_constantize
          klass&.prepend(FetchChangesets) if klass&.method_defined?(:fetch_changesets)
        end
      end

      # Repository#fetch_changesets, which Redmine runs for each SCM: the
      # import after it.
      module FetchChangesets
        def fetch_changesets(...)
          return super unless is_default? && project

          last = changesets.maximum(:id)
          result = super
          sync_issue_templates if changesets.maximum(:id) != last
          result
        end

        private

        # A failed import doesn't fail the fetch. The log names the error's
        # class only: an adapter's message may carry the repository's URL.
        def sync_issue_templates
          RepositorySource.sync(project)
        rescue Redmine::Scm::Adapters::CommandFailed, ActiveRecord::ActiveRecordError => e
          Rails.logger.error("redmine_kit_issue_template: sync of #{project.identifier} failed: #{e.class}")
        end
      end
    end
  end
end
