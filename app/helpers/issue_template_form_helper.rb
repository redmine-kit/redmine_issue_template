# frozen_string_literal: true

# Changes a method of Redmine's IssuesHelper, so it is a module of its own,
# added to the controllers after IssuesHelper (IssueTemplatesHelper is
# added before it).
module IssueTemplateFormHelper
  # The issue form offers no other project while a template applies: the
  # template's values belong to the project it was chosen in. With a single
  # project, Redmine leaves the project field out of the form.
  def projects_for_select(issue)
    return [issue.project] if issue.issue_template_active?

    super
  end
end
