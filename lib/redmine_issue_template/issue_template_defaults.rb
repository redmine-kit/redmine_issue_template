# frozen_string_literal: true

module RedmineIssueTemplate
  # The issue attributes a template sets, resolved against the project once
  # (the lookups of trackers, versions, users and custom fields run once).
  class IssueTemplateDefaults
    def initialize(template, project)
      @template = template
      @project = project
    end

    # { "tracker_id" => "2", ..., "custom_field_values" => { "3" => "x" } }
    def attributes
      @attributes ||= begin
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
        values.freeze
      end
    end

    # The values the form can't change: the template's attributes except the
    # subject, the description and the assignee, which the form starts with.
    # { "tracker_id" => "2", "3" => "x" }, custom fields by id.
    def preset
      @preset ||= begin
        values = attributes.dup
        custom = values.delete('custom_field_values') || {}
        values.except('subject', 'description', 'assigned_to_id').merge(custom).freeze
      end
    end

    # The attribute names and custom field ids the template gives a value.
    def filled
      attributes.keys | (attributes['custom_field_values'] || {}).keys
    end

    # Hidden fields are not in the form, so the template's values are set
    # directly, on every request: those Redmine lets the user set.
    def apply_to_hidden_fields(issue)
      hidden = issue.issue_template_visibility[:hidden].select { |name| issue.issue_template_settable?(name) }
      attributes.except('custom_field_values').each do |name, value|
        next unless hidden.include?(name) && issue.respond_to?("#{name}=")

        issue.public_send("#{name}=", value)
      end
      custom = (attributes['custom_field_values'] || {}).slice(*hidden)
      issue.custom_field_values = custom if custom.any?
    end

    # A new issue of the project as the template's form shows it, for the
    # preview in the project settings.
    def new_issue(user = User.current)
      issue = Issue.new(project: @project, author: user)
      # Before the template applies, which takes its values out of the form.
      issue.safe_attributes = attributes
      issue.issue_template = @template
      issue.issue_template_defaults = self
      issue.issue_template_answers = {}
      # The project's first tracker for a manager who can't add issues.
      issue.tracker ||= issue.allowed_target_trackers(user).first || @project.trackers.first
      issue.status ||= issue.default_status
      apply_to_hidden_fields(issue)
      issue
    end

    private

    def private_value(value)
      return nil if value.nil?

      value ? '1' : '0'
    end
  end
end
