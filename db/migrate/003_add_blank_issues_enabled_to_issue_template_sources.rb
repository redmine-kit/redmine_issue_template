# frozen_string_literal: true

# Whether issues can be created without a template, when config.yml doesn't say.
class AddBlankIssuesEnabledToIssueTemplateSources < ActiveRecord::Migration[7.2]
  def change
    add_column :issue_template_sources, :blank_issues_enabled, :boolean, null: false, default: true
  end
end
