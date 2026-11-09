# frozen_string_literal: true

resources :projects, only: [] do
  get 'issues/templates', to: 'issue_templates#index', as: 'issue_template_chooser'
  post 'issue_templates/sync', to: 'issue_templates#sync', as: 'sync_issue_templates'
  resources :issue_templates, only: %i[new create edit update destroy]
end
