# frozen_string_literal: true

# Issue templates for Redmine (docs/design.md): a template chooser for
# "New issue", Markdown templates, YAML issue forms and config.yml, read from
# the project's repository (.redmine/ISSUE_TEMPLATE/)
# or edited in the project settings.
module RedmineKit
  module IssueTemplate
    VERSION = '0.1.0'

    DOCS_URL = 'https://redmine-kit.github.io/redmine_issue_template/'
    # The folder read from the repository. .github/ISSUE_TEMPLATE is not read
    # (templates for Redmine live in .redmine only).
    FOLDERS = ['.redmine/ISSUE_TEMPLATE'].freeze

    # Where a project's files come from (RedmineKit::IssueTemplate::TemplateSource#kind).
    SOURCES = %w[repository github manual].freeze

    module_function

    # Rules name a custom field by its id ("3") and other fields by attribute.
    def custom_field_id?(name)
      name.to_s.match?(/\A\d+\z/)
    end

    def setup
      Project.has_many :issue_template_files, class_name: 'RedmineKit::IssueTemplate::TemplateFile',
                                              dependent: :delete_all
      Project.has_one :issue_template_source, class_name: 'RedmineKit::IssueTemplate::TemplateSource',
                                              dependent: :delete
      Issue.prepend IssuePatch
      IssuesController.prepend IssuesControllerPatch
      IssuesController.helper TemplatesHelper
      IssuesController.helper IssueFormHelper
      ProjectsHelper.prepend ProjectsHelperPatch
      RepositoryPatch.install
      # the chooser's line and a form's part of Redmine's issue form (view hooks)
      Hooks.instance
      # MCP (redmine_kit_mcp, when installed): its create_issue follows the
      # blank issue rule, and the plugin's tools make issues from templates
      McpHooks.instance
      ActiveSupport.on_load(:redmine_kit_mcp) { McpTools.register(self) }
    end
  end
end
