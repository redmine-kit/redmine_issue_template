# frozen_string_literal: true

# Added after Redmine's IssuesHelper, whose method it changes.
module IssueTemplateFormHelper
  # The issue form offers no other project while a template applies: the
  # template's values belong to the project it was chosen in. With a single
  # project, Redmine leaves the project field out of the form.
  def projects_for_select(issue)
    return [issue.project] if issue.respond_to?(:issue_template_active?) && issue.issue_template_active?

    super
  end
end
