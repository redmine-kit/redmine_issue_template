# frozen_string_literal: true

module RedmineIssueTemplate
  # The request's parameters for a template, read safely: part of
  # IssuesControllerPatch.
  module IssueTemplateParams
    private

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

    # The answers of the template's fields only: a string or a list of
    # strings each.
    def issue_template_answers_param(template = nil)
      answers = params[:issue_template_answers]
      return hash_param(answers) if template.nil?
      return {} unless answers.respond_to?(:permit)

      refs = template.form? ? template.fields.map(&:ref) : []
      answers.permit(refs.flat_map { |ref| [ref, { ref => [] }] }).to_h
    end

    # The files of the form's upload fields: { ref => [Attachment] }, from
    # the tokens of Redmine's uploads (at most 10 a field, as Redmine's Files
    # field takes).
    def issue_template_uploads_param(template)
      given = hash_param(params[:issue_template_uploads])
      uploads = template.form? ? template.fields.select { |element| element.type == 'upload' } : []
      uploads.to_h do |element|
        entries = hash_param(given[element.ref]).values.first(10)
        [element.ref, entries.filter_map { |entry| uploaded_attachment(hash_param(entry)) }]
      end
    end

    # A file the user uploaded and that is not attached yet, with the name
    # and description from the form, as Redmine's save_attachments reads them.
    def uploaded_attachment(entry)
      attachment = Attachment.find_by_token(entry['token'].to_s)
      return nil unless attachment && attachment.author_id == User.current.id

      filename = entry['filename']
      attachment.filename = filename if filename.is_a?(String) && filename.present?
      attachment.description = entry['description'].to_s.strip
      attachment
    end

    # The answers as text, under the names they were posted with.
    def issue_template_answers_text
      issue_template_answers_param.filter_map do |name, value|
        text = Array(value).map(&:to_s).reject(&:blank?).join(', ')
        "### #{name}\n\n#{text}" if text.present?
      end.join("\n\n")
    end

    # The template's values, for the fields the request doesn't give. Only
    # when the form opens: later requests carry the user's own values.
    def issue_template_defaults_into_params(template)
      defaults = issue_template_defaults(template).attributes.dup
      given = issue_params_hash
      custom = defaults.delete('custom_field_values') || {}
      merged = defaults.merge(given)
      merged['custom_field_values'] = custom.merge(hash_param(given['custom_field_values'])) if custom.any?
      params[:issue] = ActionController::Parameters.new(merged)
    end

    # Takes out of the request what it can't set while a template applies:
    # the project, hidden fields (Redmine's defaults apply, then the
    # template's values), a form's description (made from the answers) and
    # linked fields (set by the answers). The preset values go in now, before
    # Redmine assigns the attributes, so that the tracker comes first.
    # Redmine's safe_attributes stays the list of what the user may set.
    def restrict_issue_template_params(template)
      preset = issue_template_defaults(template).preset
      hidden = template.options.visibility(@project)[:hidden]
      out = issue_template_params_out(template, hidden)
      given = issue_params_hash
      @issue_template_held = hidden_input(given, hidden)
      attrs = given.except(*out)
      attrs['custom_fields'] = api_custom_fields(attrs['custom_fields'], out | preset.keys) if attrs['custom_fields']
      params[:issue] = ActionController::Parameters.new(with_preset(attrs, preset.except(*out), out))
    end

    # The attributes and custom field ids the request can't set.
    def issue_template_params_out(template, hidden)
      out = ['project_id'] | hidden
      out |= ['description'] if template.form?
      out | LinkedField.attributes(template, @project)
    end

    # The attributes with the preset values in place of the request's.
    def with_preset(attrs, preset, out)
      custom = hash_param(attrs['custom_field_values']).except(*out)
      preset.each do |name, value|
        RedmineIssueTemplate.custom_field_id?(name) ? custom[name] = value : attrs[name] = value
      end
      attrs['custom_field_values'] = custom if custom.any?
      attrs
    end

    # What the request gave for hidden fields, kept for those the form shows
    # again because Redmine requires them (restore_shown_hidden_input).
    def hidden_input(given, hidden)
      custom = hash_param(given['custom_field_values']).slice(*hidden)
      input = given.slice(*hidden)
      input['custom_field_values'] = custom if custom.any?
      input
    end

    # Hidden fields the form shows again get what was typed in them, through
    # Redmine's safe_attributes.
    def restore_shown_hidden_input(issue, template)
      shown = template.options.visibility(@project)[:hidden] - issue.issue_template_visibility[:hidden]
      return if shown.empty? || @issue_template_held.blank?

      input = @issue_template_held.slice(*shown)
      custom = hash_param(@issue_template_held['custom_field_values']).slice(*shown)
      input['custom_field_values'] = custom if custom.any?
      issue.safe_attributes = input if input.any?
    end
  end
end
