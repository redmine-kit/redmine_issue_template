# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
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
        @issue.issue_template_upload_ids = issue_template_upload_ids_param(template)
        issue_template_defaults(template).apply_to_hidden_fields(@issue)
        restore_shown_hidden_input(@issue, template)
      end

      def issue_template_set
        return nil unless issue_template_project&.module_enabled?(:issue_templates)

        @issue_template_set ||= TemplateSet.for(issue_template_project)
      end

      # The templates the user can use in the project, once per request.
      def usable_issue_templates
        @usable_issue_templates ||= issue_template_set&.usable_for(issue_template_project) || []
      end

      # The template's values, resolved once per request.
      def issue_template_defaults(template)
        @issue_template_defaults ||= IssueTemplateDefaults.new(template, issue_template_project)
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
        return unless issue_template_chooser_page?
        return if params[:copy_from].present?
        return if current_issue_template
        return if params[:issue_template] == 'blank' && issue_without_template_allowed?

        redirect_to project_issue_template_chooser_path(@project, request.query_parameters.except('issue_template'))
      end

      # Redmine's page of the form, in a project with templates: not its
      # updates, the REST API, or the new UI (redmine_kit_ui), which shows the
      # chooser as a step of its own form (KitForm), for its JSON and its page.
      def issue_template_chooser_page?
        request.get? && !request.xhr? && !api_request? && !kit_shell_page? && @project.present? &&
          usable_issue_templates.any?
      end

      def kit_shell_page?
        defined?(RedmineKit::Ui.shell_page?) && RedmineKit::Ui.shell_page?(self)
      end

      # A template that could no longer be used: the form again, with what
      # was typed (the answers in the description), rather than an issue
      # without the answers.
      def refuse_unavailable_issue_template
        return if !browser_request? || issue_template_key.nil? || @issue.nil? || @issue.issue_template_active?
        return render_issue_template_error(l(:error_issue_template_unavailable)) if api_request?

        @issue.description = issue_template_answers_text if @issue.description.blank?
        @issue.errors.add(:base, l(:error_issue_template_unavailable))
        render(:new)
      end

      # Creating an issue in the browser without a template, when the project
      # it goes to doesn't allow blank issues. The REST API and email are left
      # to Redmine; copies are not made from templates.
      def refuse_issue_without_template
        return unless issue_without_template_checked?

        project = @issue&.project || @project
        return if project.nil? || issue_without_template_allowed?(project)
        return render_issue_template_error(l(:error_issue_template_required)) if api_request?

        redirect_to_chooser_with_error(project)
      end

      # A new issue of the browser that no template applies to (a copy is made
      # from its issue, not from a template).
      def issue_without_template_checked?
        browser_request? && !@issue&.issue_template_active? && params[:copy_from].blank?
      end

      def redirect_to_chooser_with_error(project)
        flash[:error] = l(:error_issue_template_required)
        redirect_to project_issue_template_chooser_path(project)
      end

      # Redmine's form, and the new UI's requests (redmine_kit_ui's kit
      # requests: JSON with the browser's session), which come from the browser
      # too: they follow the same rules. Other JSON is the REST API, left to
      # Redmine. Whether a request is a kit request is redmine_kit_ui's rule.
      def browser_request?
        !api_request? || issue_template_kit_request?
      end

      # A kit request of the new UI (redmine_kit_ui's rule; without it, none).
      def issue_template_kit_request?
        return false unless defined?(RedmineKit::Ui.kit_request?)

        RedmineKit::Ui.kit_request?(self)
      end

      # A refusal of the new UI's create, as Redmine's REST API answers one.
      def render_issue_template_error(message)
        render json: { errors: [message] }, status: :unprocessable_content
      end

      def issue_without_template_allowed?(project = issue_template_project)
        TemplateSet.blank_issue_allowed?(project)
      end
    end
  end
end
