# frozen_string_literal: true

module RedmineIssueTemplate
  # The "Issue templates" tab of the project settings.
  module ProjectsHelperPatch
    def project_settings_tabs
      tabs = super
      if User.current.allowed_to?(:manage_issue_templates, @project) && @project.module_enabled?(:issue_templates)
        tabs << { name: 'issue_templates', action: :manage_issue_templates, partial: 'issue_templates/settings',
                  label: :label_issue_template_plural }
      end
      tabs
    end
  end
end
