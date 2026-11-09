# frozen_string_literal: true

# A template file of a project: a Markdown template, an issue form or
# config.yml, with its path in the template folder (e.g. "bug.yml").
class IssueTemplateFile < ApplicationRecord
  # A file name in the folder: no subfolders, as in GitHub's ISSUE_TEMPLATE.
  PATH = %r{\A[^/\\\x00-\x1f]+\.(md|ya?ml)\z}

  belongs_to :project

  validates :path, presence: true, format: { with: PATH }, uniqueness: { scope: :project_id }
  validates :content, length: { maximum: 65_535 }

  after_commit { RedmineIssueTemplate::TemplateSet.reset! }
end
