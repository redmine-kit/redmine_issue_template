# frozen_string_literal: true

resources :projects, only: [] do
  get 'issues/templates', to: 'issue_templates#index', as: 'issue_template_chooser'
  post 'issue_templates/sync', to: 'issue_templates#sync', as: 'sync_issue_templates'
  patch 'issue_templates/settings', to: 'issue_templates#settings', as: 'issue_template_settings'
  resources :issue_templates, only: %i[show new create edit update destroy]
end
