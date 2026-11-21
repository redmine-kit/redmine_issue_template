# frozen_string_literal: true

# The template files a project uses, where they come from and the last import
# (docs/design.md#import-and-sync).
#
# One method per table; create_table and add_index in them are recorded as in
# change, so that the migration reverses.
class CreateIssueTemplateTables < ActiveRecord::Migration[8.1]
  def change
    create_files
    create_sources
  end

  private

  def create_files
    create_table :redmine_kit_issue_template_files do |t|
      t.references :project, null: false, index: false, foreign_key: false
      t.string :path, null: false
      # A file has at most 65,535 characters, more bytes than MySQL's TEXT
      # holds: MEDIUMTEXT there. Other databases don't limit text.
      t.text :content, null: false, limit: 16.megabytes
      # A file too long to be a template is stored empty, with this mark.
      t.boolean :too_long, null: false, default: false
      t.timestamps
    end
    add_index :redmine_kit_issue_template_files, %i[project_id path], unique: true
  end

  # Where a project's template files come from, and the last import. The
  # errors and warnings are worked out from the stored files when shown.
  def create_sources
    create_table :redmine_kit_issue_template_sources do |t|
      t.references :project, null: false, index: { unique: true }, foreign_key: false
      t.string :kind, null: false, default: 'manual'
      t.string :folder
      t.string :revision
      t.string :digest
      t.datetime :synced_at
      t.timestamps
    end
  end
end
