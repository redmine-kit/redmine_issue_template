# frozen_string_literal: true

# A template file of a project: a Markdown template, a YAML form or
# config.yml, with its path in the template folder (e.g. "bug.yml").
class IssueTemplateFile < ApplicationRecord
  # A file name in the folder: no subfolders, as in ISSUE_TEMPLATE.
  PATH = %r{\A[^/\\\x00-\x1f]+\.(md|ya?ml)\z}

  belongs_to :project

  validates :path, presence: true, length: { maximum: 255 }, format: { with: PATH }, uniqueness: { scope: :project_id }
  validates :content, length: { maximum: RedmineIssueTemplate::Parser::MAX_LENGTH }
  # Files saved in the project settings get the import's input check.
  validate :check_template, on: :settings

  after_commit { RedmineIssueTemplate::TemplateSet.reset! }

  # The path is shown as Redmine's "File" (field_filename).
  def self.human_attribute_name(attribute, *)
    attribute.to_s == 'path' ? ::I18n.t(:field_filename) : super
  end

  # The project's files with this one as it is now, saved or not, parsed
  # together (template names and ids must be unique).
  def parse_with_others
    files = IssueTemplateFile.where(project_id: project_id).where.not(id: id).pluck(:path, :content).to_h
    files[path] = content.to_s
    RedmineIssueTemplate::Parser.parse(files)
  end

  # This file's errors in a parsed set of files.
  def errors_in(set)
    set.messages.select { |message| message.path == path && message.error? }
  end

  private

  # The errors the import would report for this file.
  def check_template
    return unless errors.empty?

    errors_in(parse_with_others).each { |message| errors.add(:base, message.text) }
  end
end
