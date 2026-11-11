# frozen_string_literal: true

module RedmineIssueTemplate
  # Redmine's own rules for a new issue, without the template's: part of
  # IssuePatch.
  module RedmineRules
    # Whether Redmine lets the user set the field on this issue: not one of
    # the workflow's read-only fields, the fields the tracker disables or the
    # custom fields the user can't see.
    # The user defaults to nil (User.current), for which Redmine caches the
    # workflow's rules within the issue.
    def issue_template_settable?(attribute, user = nil)
      if RedmineIssueTemplate.custom_field_id?(attribute)
        values = redmine_method(:editable_custom_field_values).call(user)
        values.any? { |value| value.custom_field_id.to_s == attribute }
      else
        redmine_method(:safe_attribute_names).call(user).include?(attribute)
      end
    end

    # Hidden fields that Redmine requires (the workflow, required custom
    # fields without a default) and the template doesn't fill: shown again,
    # or nothing could fill them.
    def issue_template_unfilled(hidden)
      filled = issue_template_defaults.filled
      required = redmine_method(:required_attribute_names).call(nil) |
                 available_custom_fields.select { |field| field.is_required? && field.default_value.blank? }
                                        .map { |field| field.id.to_s }
      hidden & (required - filled)
    end

    private

    # The method as it is after IssuePatch: Redmine's, or another plugin's
    # that comes later, whatever the order the plugins were loaded in.
    def redmine_method(name)
      IssuePatch.instance_method(name).bind(self).super_method
    end
  end
end
