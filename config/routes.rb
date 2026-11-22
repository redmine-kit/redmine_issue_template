# frozen_string_literal: true

# RedmineKit::IssueTemplate::TemplatesController, at the URLs of Redmine's
# project resources.
resources :projects, only: [] do
  scope controller: 'redmine_kit/issue_template/templates' do
    get 'issues/templates', action: :index, as: 'issue_template_chooser'
    # the settings tab's data for the new UI (JSON; Redmine's page is the settings tab)
    get 'issue_templates', action: :files, as: 'issue_template_files'
    post 'issue_templates/sync', action: :sync, as: 'sync_issue_templates'
    # PUT too: the new UI's requests (redmine_kit_ui's kitApi) have no PATCH
    match 'issue_templates/settings', action: :settings, as: 'issue_template_settings', via: %i[patch put]
    # 共有 (the projects the templates are shared with)
    match 'issue_templates/sharing', action: :sharing, as: 'issue_template_sharing', via: %i[patch put]
    # the new UI's preview of a file as typed (JSON only)
    post 'issue_templates/preview', action: :preview, as: 'preview_issue_templates', format: true,
                                    constraints: { format: 'json' }
  end
  resources :issue_templates, only: %i[show new create edit update destroy],
                              controller: 'redmine_kit/issue_template/templates'
end
