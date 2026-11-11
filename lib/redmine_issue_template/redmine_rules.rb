# frozen_string_literal: true

module RedmineIssueTemplate
  # Redmine's own rules for a new issue, without the template's: part of
  # IssuePatch.
  module RedmineRules
    # Whether Redmine lets the user set the field on this issue: not one of
    # the workflow's read-only fields, the fields the tracker disables or the
    # custom fields the user can't see.
    def issue_template_settable?(attribute, user = User.current)
      if attribute.match?(/\A\d+\z/)
        values = redmine_method(:editable_custom_field_values).call(user)
        values.any? { |value| value.custom_field_id.to_s == attribute }
      else
        redmine_method(:safe_attribute_names).call(user).include?(attribute)
      end
    end

    private

    # The method as it is after IssuePatch: Redmine's, or another plugin's
    # that comes later, whatever the order the plugins were loaded in.
    def redmine_method(name)
      IssuePatch.instance_method(name).bind(self).super_method
    end
  end
end
