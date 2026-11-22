# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # A template applied to a new issue, the one way every path makes an issue
    # from a template: Redmine's issues#new and #create (IssuesControllerPatch:
    # the classic form and the new UI) and the MCP tool
    # issue_template.create_issue (McpTools).
    #
    # Before Redmine's safe_attributes: the template's values for what the
    # request doesn't give (#with_defaults, when the form opens or for a request
    # that never saw the form), and what the request can't set while the
    # template applies taken out (#restricted). After it: the template on the
    # issue, its values in the hidden fields, and what was given for hidden
    # fields that the form shows again because Redmine requires them (#apply).
    class TemplateApplication
      attr_reader :template, :project, :defaults

      def initialize(template, project)
        @template = template
        @project = project
        @defaults = IssueTemplateDefaults.new(template, project)
      end

      # The template's values, for the fields the given attributes don't give.
      def with_defaults(given)
        values = defaults.attributes.dup
        custom = values.delete('custom_field_values') || {}
        merged = values.merge(given)
        merged['custom_field_values'] = custom.merge(hash_param(given['custom_field_values'])) if custom.any?
        merged
      end

      # The given attributes without what they can't set while the template
      # applies: the project (with pin_project, the template's project instead),
      # hidden fields (Redmine's defaults apply, then the template's values), a
      # form's description (made from the answers) and linked fields (set by the
      # answers). The preset values go in now, before Redmine assigns the
      # attributes, so that the tracker comes first. Redmine's safe_attributes
      # stays the list of what the user may set.
      def restricted(given, pin_project: false)
        preset = defaults.preset
        out = params_out
        @held = hidden_input(given)
        attrs = given.except(*out)
        attrs['custom_fields'] = api_custom_fields(attrs['custom_fields'], out | preset.keys) if attrs['custom_fields']
        attrs = with_preset(attrs, preset.except(*out), out)
        pin_project ? attrs.merge('project_id' => project.id.to_s) : attrs
      end

      # The template on the issue Redmine built with the restricted attributes.
      def apply(issue, answers: {}, uploads: {}, upload_ids: {})
        issue.issue_template = template
        issue.issue_template_defaults = defaults
        issue.issue_template_answers = answers
        issue.issue_template_uploads = uploads
        issue.issue_template_upload_ids = upload_ids
        defaults.apply_to_hidden_fields(issue)
        restore_shown_hidden_input(issue)
        issue
      end

      private

      def hidden
        @hidden ||= template.options.visibility(project)[:hidden]
      end

      # The attributes and custom field ids the request can't set.
      def params_out
        out = ['project_id'] | hidden
        out |= ['description'] if template.form?
        out | LinkedField.attributes(template, project)
      end

      # The attributes with the preset values in place of the request's.
      def with_preset(attrs, preset, out)
        custom = hash_param(attrs['custom_field_values']).except(*out)
        preset.each do |name, value|
          RedmineKit::IssueTemplate.custom_field_id?(name) ? custom[name] = value : attrs[name] = value
        end
        attrs['custom_field_values'] = custom if custom.any?
        attrs
      end

      # What the request gave for hidden fields, kept for those the form shows
      # again because Redmine requires them (restore_shown_hidden_input).
      def hidden_input(given)
        custom = hash_param(given['custom_field_values']).slice(*hidden)
        input = given.slice(*hidden)
        input['custom_field_values'] = custom if custom.any?
        input
      end

      # Hidden fields the form shows again get what was given for them, through
      # Redmine's safe_attributes.
      def restore_shown_hidden_input(issue)
        shown = hidden - issue.issue_template_visibility[:hidden]
        return if shown.empty? || @held.blank?

        input = @held.slice(*shown)
        custom = hash_param(@held['custom_field_values']).slice(*shown)
        input['custom_field_values'] = custom if custom.any?
        issue.safe_attributes = input if input.any?
      end

      # The REST API's form of custom field values, without the given ids.
      def api_custom_fields(fields, ids)
        Array(fields).select { |field| field.is_a?(Hash) && !ids.include?(field['id'].to_s) }
      end

      # A value that should be a hash, or an empty hash.
      def hash_param(value)
        return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

        value.is_a?(Hash) ? value : {}
      end
    end
  end
end
