# frozen_string_literal: true

# Where a project's template files come from, and the last import.
class CreateIssueTemplateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :issue_template_sources do |t|
      t.references :project, null: false, index: { unique: true }, foreign_key: false
      t.string :kind, null: false, default: 'manual'
      t.string :folder
      t.string :revision
      t.string :digest
      t.datetime :synced_at
      t.text :messages
      t.timestamps
    end
  end
end
