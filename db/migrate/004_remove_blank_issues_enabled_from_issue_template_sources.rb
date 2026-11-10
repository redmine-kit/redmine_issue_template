# frozen_string_literal: true

# Blank issues are set in config.yml only, also from the project settings.
class RemoveBlankIssuesEnabledFromIssueTemplateSources < ActiveRecord::Migration[7.2]
  def change
    remove_column :issue_template_sources, :blank_issues_enabled, :boolean, null: false, default: true
  end
end
