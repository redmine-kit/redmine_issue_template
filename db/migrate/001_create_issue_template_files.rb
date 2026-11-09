# frozen_string_literal: true

# The template files a project uses (docs/design.md#import-and-sync).
class CreateIssueTemplateFiles < ActiveRecord::Migration[7.2]
  def change
    create_table :issue_template_files do |t|
      t.references :project, null: false, index: false, foreign_key: false
      t.string :path, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :issue_template_files, %i[project_id path], unique: true
  end
end
