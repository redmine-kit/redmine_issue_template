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
               { issue_templates: %i[files sync settings show new create edit update destroy], projects: :settings },
               require: :member
  end
end

RedmineIssueTemplate.setup

# The new UI (redmine_kit_ui's docs/plugins-kit.md): what this plugin adds to
# it, declared in Ruby next to the permission it names. Rails' load hook of
# redmine_kit_ui: it runs once redmine_kit_ui has loaded, whichever plugin
# Redmine loads first, and never without it (the plugin works as it is then).
# The components are frontend/src's, built into
# assets/javascripts/kit/issue_template.js; labels are this plugin's locale keys.
ActiveSupport.on_load(:redmine_kit_ui) do
  kit_ui :redmine_issue_template do
    api_version 1
    module_path 'kit/issue_template.js'
    # New issue: the chooser as a step before the form, then the template's
    # part at the form's top (KitForm answers which applies)
    new_issue :template, permission: :add_issues, params: %i[issue_template issue_template_answers],
                         chooser: 'IssueTemplateChooser', section: 'IssueTemplateSection'
    # Project settings › Issue templates, and the file forms it opens
    project_settings :issue_templates, label: :label_issue_template_plural, permission: :manage_issue_templates,
                                       component: 'IssueTemplateSettings'
    screen path: '/projects/:project_id/issue_templates/new', component: 'IssueTemplateEdit', menu_item: :settings,
           permission: :manage_issue_templates, title: :label_issue_template_file_new
    screen path: '/projects/:project_id/issue_templates/:id/edit', component: 'IssueTemplateEdit',
           menu_item: :settings, permission: :manage_issue_templates, title: :label_issue_template_plural
  end
end
