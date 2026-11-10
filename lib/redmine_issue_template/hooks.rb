# frozen_string_literal: true

module RedmineIssueTemplate
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_new_top, partial: 'issue_templates/intro'
    render_on :view_issues_form_details_top, partial: 'issue_templates/form_key'
  end
end
