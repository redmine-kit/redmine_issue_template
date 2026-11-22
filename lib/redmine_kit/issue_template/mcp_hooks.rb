# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # redmine_kit_mcp's hook of a new issue (create_issue, and this plugin's
    # issue_template.create_issue): an issue made through MCP follows the
    # project's blank issue rule as one of the browser does
    # (IssuePatch#issue_template_missing?, refused by its validation).
    class McpHooks < Redmine::Hook::Listener
      def mcp_create_issue_before_save(context)
        issue = context[:issue]
        issue.issue_template_check = true if issue.is_a?(::Issue)
      end
    end
  end
end
