# frozen_string_literal: true

module RedmineIssueTemplate
  # "New issue" opens the template chooser when the project has templates;
  # the chosen template (params[:issue_template]) fills in the form.
  module IssuesControllerPatch
    include IssueTemplateParams

    def self.prepended(base)
      # After build_new_issue_from_params, so that Redmine's own checks
      # (trackers, permissions) come first.
      base.before_action :redirect_to_issue_template_chooser, only: :new
      base.before_action :refuse_unavailable_issue_template, only: :create
      base.before_action :refuse_issue_without_template, only: :create
    end

    private

    # "Create and continue" opens the same template again: Redmine's URL for
    # the next issue, with the template.
    def redirect_after_create
      super
      return unless params[:continue] && @issue&.issue_template && response.location

      location = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(location.query).merge('issue_template' => @issue.issue_template.key)
      location.query = query.to_query
      response.location = location.to_s
    end

    def build_new_issue_from_params
      template = current_issue_template
      if template
        issue_template_defaults_into_params(template) if request.get?
        restrict_issue_template_params(template)
      end
      super
      return if performed? || template.nil? || @issue.nil?

      @issue.issue_template = template
      @issue.issue_template_defaults = issue_template_defaults(template)
      @issue.issue_template_answers = issue_template_answers_param(template)
      @issue.issue_template_uploads = issue_template_uploads_param(template)
      issue_template_defaults(template).apply_to_hidden_fields(@issue)
      restore_shown_hidden_input(@issue, template)
    end

    def issue_template_set
      return nil unless @project&.module_enabled?(:issue_templates)

      @issue_template_set ||= TemplateSet.for(@project)
    end

    # The templates the user can use in the project, once per request.
    def usable_issue_templates
      @usable_issue_templates ||= issue_template_set&.usable_for(@project) || []
    end

    # The template's values, resolved once per request.
    def issue_template_defaults(template)
      @issue_template_defaults ||= IssueTemplateDefaults.new(template, @project)
    end

    # The template the request names: nil for none and for "blank".
    def issue_template_key
      key = params[:issue_template].to_s
      key unless key.blank? || key == 'blank'
    end

    def current_issue_template
      key = issue_template_key
      usable_issue_templates.detect { |template| template.key == key } if key
    end

    def redirect_to_issue_template_chooser
      return unless request.get? && !request.xhr? && @project && usable_issue_templates.any?
      return if params[:copy_from].present?
      return if current_issue_template
      return if params[:issue_template] == 'blank' && issue_without_template_allowed?

      redirect_to project_issue_template_chooser_path(@project, request.query_parameters.except('issue_template'))
    end

    # A template that could no longer be used: the form again, with what
    # was typed (the answers in the description), rather than an issue
    # without the answers.
    def refuse_unavailable_issue_template
      return if api_request? || issue_template_key.nil? || @issue.nil? || @issue.issue_template_active?

      @issue.description = issue_template_answers_text if @issue.description.blank?
      @issue.errors.add(:base, l(:error_issue_template_unavailable))
      render(:new)
    end

    # Creating an issue in the browser without a template, when the project
    # it goes to doesn't allow blank issues. The REST API and email are left
    # to Redmine; copies are not made from templates.
    def refuse_issue_without_template
      return if api_request? || @issue&.issue_template_active? || params[:copy_from].present?

      project = @issue&.project || @project
      return if project.nil? || issue_without_template_allowed?(project)

      flash[:error] = l(:error_issue_template_required)
      redirect_to project_issue_template_chooser_path(project)
    end

    def issue_without_template_allowed?(project = @project)
      return true unless project.module_enabled?(:issue_templates)
      return true if User.current.allowed_to?(:manage_issue_templates, project)

      set = project == @project ? issue_template_set : TemplateSet.for(project)
      set.config.blank_issues_enabled? || (project == @project ? usable_issue_templates : set.usable_for(project)).none?
    end
  end
end
