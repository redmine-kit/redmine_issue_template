# frozen_string_literal: true

# The template files a project uses (docs/design.md#import-and-sync).
class CreateIssueTemplateFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :issue_template_files do |t|
      t.references :project, null: false, index: false, foreign_key: false
      t.string :path, null: false
      # A file has at most 65,535 characters, more bytes than MySQL's TEXT
      # holds: MEDIUMTEXT there. Other databases don't limit text.
      t.text :content, null: false, limit: 16.megabytes
      # A file too long to be a template is stored empty, with this mark.
      t.boolean :too_long, null: false, default: false
      t.timestamps
    end
    add_index :issue_template_files, %i[project_id path], unique: true
  end
end
