# frozen_string_literal: true

# A file may have 65,535 characters, more bytes than MySQL's TEXT holds:
# MEDIUMTEXT there. Other databases don't limit text.
class WidenIssueTemplateFileContent < ActiveRecord::Migration[7.2]
  def up
    change_column :issue_template_files, :content, :text, limit: 16.megabytes, null: false
  end

  def down
    change_column :issue_template_files, :content, :text, null: false
  end
end
