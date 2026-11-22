# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # The request's parameters for a template, read safely: part of
    # IssuesControllerPatch. They belong to the template's project
    # (IssueTemplateProject); what the template does to the issue's
    # attributes is TemplateApplication's.
    module IssueTemplateParams
      include IssueTemplateProject

      private

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
      # field takes). A field given as a list (the new UI) names attachment ids
      # instead (issue_template_upload_ids_param).
      def issue_template_uploads_param(template)
        given = hash_param(params[:issue_template_uploads])
        template.uploads.to_h do |element|
          entries = given[element.ref].is_a?(Array) ? [] : hash_param(given[element.ref]).values.first(10)
          [element.ref, entries.filter_map { |entry| uploaded_attachment(hash_param(entry)) }]
        end
      end

      # The new UI's upload fields: { ref => [attachment id] }. The app sends
      # the files themselves in Redmine's own `uploads`, and the plugin never
      # sees their tokens: an id only names a file of the issue's uploads
      # (IssueTemplateAnswers#issue_template_uploads), so it can't reach a file
      # the request didn't give Redmine. Ids are digits, at most 10 a field.
      def issue_template_upload_ids_param(template)
        given = hash_param(params[:issue_template_uploads])
        template.uploads.to_h do |element|
          list = given[element.ref]
          ids = list.is_a?(Array) ? list.grep(String).grep(/\A\d{1,12}\z/).first(10).map(&:to_i) : []
          [element.ref, ids]
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
    end
  end
end
