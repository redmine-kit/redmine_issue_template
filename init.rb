# frozen_string_literal: true

require_relative 'lib/redmine_kit/issue_template'

Redmine::Plugin.register :redmine_kit_issue_template do
  name 'Redmine Kit Issue Template'
  author 'Redmine Kit'
  description 'Issue templates'
  version RedmineKit::IssueTemplate::VERSION
  url 'https://github.com/redmine-kit/redmine_issue_template'
  author_url 'https://github.com/redmine-kit'
  requires_redmine version_or_higher: '7.0.0'

  project_module :issue_templates do
    permission :manage_issue_templates,
               { issue_templates: %i[files sync settings show new create edit update destroy preview],
                 projects: :settings },
               require: :member
  end
end

RedmineKit::IssueTemplate.setup

# The new UI (redmine_kit_ui's docs/plugins-kit.md): what this plugin adds to
# it, declared in Ruby next to the permission it names. Rails' load hook of
# redmine_kit_ui: it runs once redmine_kit_ui has loaded, whichever plugin
# Redmine loads first, and never without it (the plugin works as it is then).
# The components are frontend/src's, built into
# assets/javascripts/kit/issue_template.js; labels are this plugin's locale keys.
ActiveSupport.on_load(:redmine_kit_ui) do
  kit_ui :redmine_kit_issue_template do
    api_version 1
    module_path 'kit/issue_template.js'
    # assets/stylesheets/kit/issue_template.css: the utilities the module's source uses (built with it)
    stylesheet 'kit/issue_template.css'
    # New issue: the chooser as a step before the form, then the template's
    # part: its line at the form's top, a YAML form's fields after the
    # subject, the page's sidebar (where the templates come from, the fields
    # the template hides); KitForm answers which applies, and has the app show
    # the values the template sets at their fields and fold a form's other
    # fields. The upload fields' files go with Redmine's own uploads; the part
    # names them by id.
    new_issue :template, permission: :add_issues,
                         params: %i[issue_template issue_template_answers issue_template_uploads],
                         chooser: 'IssueTemplateChooser', section: 'IssueTemplateSection',
                         sections: [{ component: 'IssueTemplateFields', after: :subject }],
                         sidebar: 'IssueTemplateSidebar'
    # Project settings › Issue templates, and the file forms it opens (in a
    # drawer from the tab; these screens for their URLs, beside the tabs)
    project_settings :issue_templates, label: :label_issue_template_plural, permission: :manage_issue_templates,
                                       component: 'IssueTemplateSettings'
    screen path: '/projects/:project_id/issue_templates/new', component: 'IssueTemplateEdit', menu_item: :settings,
           permission: :manage_issue_templates, title: :label_issue_template_file_new, settings_tab: :issue_templates
    screen path: '/projects/:project_id/issue_templates/:id/edit', component: 'IssueTemplateEdit',
           menu_item: :settings, permission: :manage_issue_templates, title: :label_issue_template_plural,
           settings_tab: :issue_templates
  end
end
