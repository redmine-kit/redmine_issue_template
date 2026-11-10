# frozen_string_literal: true

module RedmineIssueTemplate
  # "New issue" opens the template chooser when the project has templates;
  # the chosen template (params[:issue_template]) fills in the form.
  module IssuesControllerPatch
    def self.prepended(base)
      # After build_new_issue_from_params, so that Redmine's own checks
      # (trackers, permissions) come first.
      base.before_action :redirect_to_issue_template_chooser, only: :new
    end

    private

    def build_new_issue_from_params
      template = current_issue_template
      if template
        issue_template_defaults_into_params(template) if request.get?
        restrict_issue_template_params(template)
      end
      super
      return if performed? || template.nil? || @issue.nil?

      @issue.issue_template = template
      @issue.issue_template_answers = issue_template_answers_param
      IssueTemplateDefaults.new(template, @project).apply_hidden(@issue)
    end

    def issue_template_set
      return nil unless @project&.module_enabled?(:issue_templates)

      @issue_template_set ||= TemplateSet.for(@project)
    end

    def current_issue_template
      key = params[:issue_template].to_s
      return nil if key.blank? || key == 'blank'

      issue_template_set&.find(key)
    end

    def redirect_to_issue_template_chooser
      return unless request.get? && !request.xhr? && @project && issue_template_set&.any?
      return if params[:copy_from].present?

      key = params[:issue_template].to_s
      return if current_issue_template
      return if key == 'blank' && (issue_template_set.config.blank_issues_enabled? ||
                                   User.current.allowed_to?(:manage_issue_templates, @project))

      redirect_to project_issue_template_chooser_path(@project, request.query_parameters.except('issue_template'))
    end

    # The template's values, for the fields the request doesn't give. Only
    # when the form opens: later requests carry the user's own values.
    def issue_template_defaults_into_params(template)
      defaults = IssueTemplateDefaults.new(template, @project).attributes
      given = issue_params_hash
      custom = defaults.delete('custom_field_values') || {}
      merged = defaults.merge(given)
      merged['custom_field_values'] = custom.merge(hash_param(given['custom_field_values'])) if custom.any?
      params[:issue] = ActionController::Parameters.new(merged)
    end

    # Takes out of the request what it can't set while a template applies:
    # the project, hidden and linked fields. The fixed values go in now,
    # before Redmine assigns the attributes, so that the tracker comes first.
    def restrict_issue_template_params(template)
      fixed = IssueTemplateDefaults.new(template, @project).fixed
      out = template.options.visibility(@project)[:hidden] | ['project_id']
      out |= ['description'] if template.form?
      out |= LinkedField.attributes(template, @project)
      attrs = issue_params_hash.except(*out)
      custom = hash_param(attrs['custom_field_values']).except(*out)
      attrs['custom_fields'] = api_custom_fields(attrs['custom_fields'], out | fixed.keys) if attrs['custom_fields']
      fixed.except(*out).each do |name, value|
        if name.match?(/\A\d+\z/)
          custom[name] = value
        else
          attrs[name] = value
        end
      end
      attrs['custom_field_values'] = custom if custom.any?
      params[:issue] = ActionController::Parameters.new(attrs)
    end

    # The REST API's form of custom field values, without the given ids.
    def api_custom_fields(fields, ids)
      Array(fields).select { |field| field.is_a?(Hash) && !ids.include?(field['id'].to_s) }
    end

    def issue_params_hash
      hash_param(params[:issue])
    end

    # A parameter that should be a hash, or an empty hash.
    def hash_param(value)
      return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

      value.is_a?(Hash) ? value : {}
    end

    def issue_template_answers_param
      hash_param(params[:issue_template_answers])
    end
  end

  # The issue attributes a template sets, resolved against the project.
  class IssueTemplateDefaults
    def initialize(template, project)
      @template = template
      @project = project
    end

    def attributes
      options = @template.options
      values = {
        'tracker_id' => @template.tracker(@project)&.id,
        'subject' => @template.title,
        'description' => @template.form? ? nil : @template.body,
        'priority_id' => options.priority_record&.id,
        'category_id' => options.category_record(@project)&.id,
        'fixed_version_id' => options.fixed_version_record(@project)&.id,
        'assigned_to_id' => @template.assignee(@project)&.id,
        'is_private' => private_value(options.is_private)
      }.compact.transform_values { |value| value.is_a?(Integer) ? value.to_s : value }
      custom = options.custom_field_values(@project)
      values['custom_field_values'] = custom if custom.any?
      values
    end

    # The values the form can't change: the template's attributes except the
    # subject, the description and the assignee, which the form starts with.
    # { "tracker_id" => "2", "3" => "x" }, custom fields by id.
    def fixed
      values = attributes
      custom = values.delete('custom_field_values') || {}
      values.except('subject', 'description', 'assigned_to_id').merge(custom)
    end

    # Hidden fields are not in the form, so the template's values are set
    # directly, on every request: those Redmine lets the user set.
    def apply_hidden(issue)
      defaults = attributes
      hidden = issue.issue_template_visibility[:hidden].select { |name| issue.issue_template_settable?(name) }
      defaults.except('custom_field_values').each do |name, value|
        next unless hidden.include?(name) && issue.respond_to?("#{name}=")

        issue.public_send("#{name}=", value)
      end
      custom = (defaults['custom_field_values'] || {}).slice(*hidden)
      issue.custom_field_values = custom if custom.any?
    end

    # A new issue of the project as the template's form shows it, for the
    # preview in the project settings.
    def new_issue(user = User.current)
      issue = Issue.new(project: @project, author: user)
      # Before the template applies, which takes its values out of the form.
      issue.safe_attributes = attributes
      issue.issue_template = @template
      issue.issue_template_answers = {}
      # The project's first tracker for a manager who can't add issues.
      issue.tracker ||= issue.allowed_target_trackers(user).first || @project.trackers.first
      issue.status ||= issue.default_status
      apply_hidden(issue)
      issue
    end

    private

    def private_value(value)
      return nil if value.nil?

      value ? '1' : '0'
    end
  end
end
