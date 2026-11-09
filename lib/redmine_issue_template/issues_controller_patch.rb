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
        remove_issue_template_hidden_params(template)
      end
      super
      return if performed? || template.nil? || @issue.nil?

      @issue.issue_template = template
      @issue.issue_template_answers = issue_template_answers_param
      apply_issue_template_hidden_values(template)
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

    # The template's values, for the fields the request doesn't give.
    def issue_template_defaults_into_params(template)
      defaults = IssueTemplateDefaults.new(template, @project).attributes
      given = params[:issue].respond_to?(:to_unsafe_h) ? params[:issue].to_unsafe_h : {}
      custom = defaults.delete('custom_field_values') || {}
      merged = defaults.merge(given)
      merged['custom_field_values'] = custom.merge(given['custom_field_values'] || {}) if custom.any?
      params[:issue] = ActionController::Parameters.new(merged)
    end

    # Fields the template hides can't be given by the request: Redmine's
    # defaults apply, then the template's values.
    def remove_issue_template_hidden_params(template)
      return unless params[:issue].respond_to?(:to_unsafe_h)

      hidden = template.options.visibility(@project)[:hidden]
      hidden |= ['description'] if template.form?
      attrs = params[:issue].to_unsafe_h.except(*hidden)
      if attrs['custom_field_values'].is_a?(Hash)
        attrs['custom_field_values'] =
          attrs['custom_field_values'].except(*hidden)
      end
      params[:issue] = ActionController::Parameters.new(attrs)
    end

    # Hidden fields are not in the form, so the template's values are set
    # directly, on every request.
    def apply_issue_template_hidden_values(template)
      defaults = IssueTemplateDefaults.new(template, @project).attributes
      hidden = @issue.issue_template_visibility[:hidden]
      defaults.except('custom_field_values').each do |name, value|
        next unless hidden.include?(name) && @issue.respond_to?("#{name}=")

        @issue.public_send("#{name}=", value)
      end
      custom = (defaults['custom_field_values'] || {}).slice(*hidden)
      @issue.custom_field_values = custom if custom.any?
    end

    def issue_template_answers_param
      answers = params[:issue_template_answers]
      return {} if answers.blank?

      answers.respond_to?(:to_unsafe_h) ? answers.to_unsafe_h : answers.to_h
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

    private

    def private_value(value)
      return nil if value.nil?

      value ? '1' : '0'
    end
  end
end
