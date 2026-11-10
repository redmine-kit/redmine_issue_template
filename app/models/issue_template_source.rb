# frozen_string_literal: true

# Where a project's template files come from (repository, github or manual),
# the revision and time of the last import, and the errors and warnings of
# the files.
class IssueTemplateSource < ApplicationRecord
  belongs_to :project

  validates :kind, inclusion: { in: RedmineIssueTemplate::SOURCES }

  def self.for(project)
    find_or_initialize_by(project_id: project.id)
  end

  # The errors and warnings of the project's files: those of the last import
  # when there is a source, else those of the stored files.
  def self.messages_for(project, source)
    source ? source.message_list : RedmineIssueTemplate::TemplateSet.for(project).messages
  end

  # Whether issues can be created without a template: config.yml's
  # blank_issues_enabled, or else the project settings.
  def self.blank_issues_enabled?(project, config)
    return config.blank_issues_enabled? if config.blank_issues_set?

    find_by(project_id: project.id)&.blank_issues_enabled != false
  end

  # Files from the repository or GitHub are edited there, not in Redmine.
  def manual?
    kind == 'manual'
  end

  def message_list
    JSON.parse(messages.presence || '[]').map { |hash| RedmineIssueTemplate::Message.from_h(hash) }
  rescue JSON::ParserError
    []
  end

  def message_list=(list)
    self.messages = list.map(&:to_h).to_json
  end
end
