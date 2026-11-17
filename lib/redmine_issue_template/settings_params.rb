# frozen_string_literal: true

module RedmineIssueTemplate
  # The settings' requests of IssueTemplatesController, read safely (a
  # value of another shape is ignored), and the new UI's answer to a save.
  # Part of the controller.
  module SettingsParams
    private

    # config.yml as the settings form gives it (the new UI's JSON: true).
    def chooser_config_content
      blank = ['1', 'true', true].include?(params[:blank_issues_enabled])
      RedmineIssueTemplate::ChooserConfig.dump(blank_issues_enabled: blank,
                                               contact_links: contact_links_param)
    end

    def file_params
      file = params.fetch(:issue_template_file, {})
      file = file.respond_to?(:permit) ? file.permit(:path, :content) : {}
      { path: file[:path], content: file[:content].to_s }
    end

    # The form's contact links, without the empty rows.
    def contact_links_param
      rows = params[:contact_links]
      return [] unless rows.is_a?(Array)

      rows.filter_map do |row|
        next unless row.respond_to?(:permit)

        permitted = row.permit(:name, :url, :about)
        link = %w[name url about].to_h { |key| [key, permitted[key].to_s.gsub("\r\n", "\n").strip] }
        link if link.values.any?(&:present?)
      end
    end

    # A save of the new UI: 201 with the file's id, 204, or 422 with the
    # file's messages.
    def render_saved(saved, file, created: false)
      return render json: { errors: file.errors.full_messages }, status: :unprocessable_content unless saved
      return render json: { issue_template_file: { id: file.id } }, status: :created if created

      head :no_content
    end
  end
end
