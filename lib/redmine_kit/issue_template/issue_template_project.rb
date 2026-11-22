# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # The project of a new issue whose templates apply, decided as Redmine
    # decides it: part of IssuesControllerPatch (through IssueTemplateParams).
    module IssueTemplateProject
      private

      # The project the new issue goes to, whose templates apply: the URL's,
      # else (Redmine's "New issue" outside a project, where the form picks the
      # project) the one Redmine's build_new_issue_from_params sets from
      # issue[project_id], or for the form's GET the first project the user may
      # add issues to. Redmine's own Issue#safe_attributes= decides it, on an
      # issue of its own: an id or an identifier, of a project the user may add
      # issues to. KitForm reads the built issue's project, which is this one
      # (the template keeps the project: TemplateApplication#restricted).
      def issue_template_project
        return @project if @project
        return @issue_template_project if defined?(@issue_template_project)

        issue = Issue.new
        # the form's default project, as Redmine's for GET; never for create (a HEAD gets it too: it has no body)
        issue.project = issue.allowed_target_projects.first unless request.post?
        issue.safe_attributes = issue_params_hash.slice('project_id')
        @issue_template_project = issue.project
      end
    end
  end
end
