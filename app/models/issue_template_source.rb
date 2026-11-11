# frozen_string_literal: true

# Where a project's template files come from (repository, github or manual),
# and the revision, time and digest of the last import.
class IssueTemplateSource < ApplicationRecord
  belongs_to :project

  validates :kind, inclusion: { in: RedmineIssueTemplate::SOURCES }

  def self.for(project)
    find_or_initialize_by(project_id: project.id)
  end

  # The errors and warnings of the project's files, from the stored files:
  # the files' own, and those that depend on the project (names it doesn't
  # have).
  def self.messages_for(project)
    set = RedmineIssueTemplate::TemplateSet.for(project)
    set.messages + set.usable.flat_map { |template| template.project_warnings(project) }
  end

  # Files from the repository or GitHub are edited there, not in Redmine.
  def manual?
    kind == 'manual'
  end
end
