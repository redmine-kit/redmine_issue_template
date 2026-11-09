# frozen_string_literal: true

module RedmineIssueTemplate
  # The issue form keeps the chosen template across its updates and shows an
  # issue form's fields after the issue's attributes.
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_form_details_top, partial: 'issue_templates/form_key'
    render_on :view_issues_form_details_bottom, partial: 'issue_templates/form_fields'
  end
end
