# frozen_string_literal: true

# Issue templates for Redmine (docs/design.md): a template chooser for
# "New issue", Markdown templates, YAML issue forms and config.yml, read from
# the project's repository (.redmine/ISSUE_TEMPLATE/ or .github/ISSUE_TEMPLATE/)
# or edited in the project settings.
module RedmineIssueTemplate
  VERSION = '0.1.0'

  DOCS_URL = 'https://redmine-kit.github.io/redmine_issue_template/'
  # The folders read from the repository: the first one with template files wins.
  FOLDERS = ['.redmine/ISSUE_TEMPLATE', '.github/ISSUE_TEMPLATE'].freeze

  # Where a project's files come from (IssueTemplateSource#kind).
  SOURCES = %w[repository github manual].freeze

  module_function

  # Rules name a custom field by its id ("3") and other fields by attribute.
  def custom_field_id?(name)
    name.to_s.match?(/\A\d+\z/)
  end

  def setup
    %w[yaml_nodes message parser redmine_options linked_field template markdown_template redmine_rules
       issue_form_checks issue_form chooser_config template_set body_composer importer repository_source
       issue_template_defaults issue_template_answers issue_patch issue_template_params issues_controller_patch
       projects_helper_patch repository_patch hooks].each do |file|
      require_relative "redmine_issue_template/#{file}"
    end
    Project.has_many :issue_template_files, dependent: :delete_all
    Project.has_one :issue_template_source, dependent: :delete
    Issue.prepend IssuePatch
    IssuesController.prepend IssuesControllerPatch
    IssuesController.helper IssueTemplatesHelper
    IssuesController.helper IssueTemplateFormHelper
    ProjectsHelper.prepend ProjectsHelperPatch
    RepositoryPatch.install
  end
end
