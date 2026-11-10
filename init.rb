# frozen_string_literal: true

require_relative 'lib/redmine_issue_template'

Redmine::Plugin.register :redmine_issue_template do
  name 'Redmine Issue Template'
  author 'Redmine Kit'
  description 'Issue templates: a template chooser for New issue, Markdown templates and YAML forms'
  version RedmineIssueTemplate::VERSION
  url 'https://github.com/redmine-kit/redmine_issue_template'
  author_url 'https://github.com/redmine-kit'
  requires_redmine version_or_higher: '7.0.0'

  project_module :issue_templates do
    permission :manage_issue_templates,
               { issue_templates: %i[sync settings show new create edit update destroy] },
               require: :member
  end
end

RedmineIssueTemplate.setup
