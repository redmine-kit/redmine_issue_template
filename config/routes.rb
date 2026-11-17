# frozen_string_literal: true

resources :projects, only: [] do
  get 'issues/templates', to: 'issue_templates#index', as: 'issue_template_chooser'
  # the settings tab's data for the new UI (JSON; Redmine's page is the settings tab)
  get 'issue_templates', to: 'issue_templates#files', as: 'issue_template_files'
  post 'issue_templates/sync', to: 'issue_templates#sync', as: 'sync_issue_templates'
  # PUT too: the new UI's requests (redmine_kit_ui's kitApi) have no PATCH
  match 'issue_templates/settings', to: 'issue_templates#settings', as: 'issue_template_settings', via: %i[patch put]
  resources :issue_templates, only: %i[show new create edit update destroy]
end
