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

    def issue_template_answers_param
      hash_param(params[:issue_template_answers])
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
