# frozen_string_literal: true

module RedmineIssueTemplate
  # A form's answers and uploaded files on a new issue: the description made
  # from them, their checks, and the files attached. Part of IssuePatch.
  module IssueTemplateAnswers
    # The files of a form's upload fields: { ref => [Attachment] }, given by
    # the controller (IssueTemplateParams#issue_template_uploads_param).
    def issue_template_uploads
      @issue_template_uploads || {}
    end

    def issue_template_composer
      BodyComposer.new(issue_template, issue_template_answers,
                       files: issue_template_uploads.transform_values { |list| list.map(&:filename) },
                       linked: issue_template_links.map(&:element), dropped: issue_template_dropped)
    end

    private

    # The upload fields' files become the issue's files, as Redmine attaches
    # the files of its own Files field.
    def attach_issue_template_uploads
      issue_template_uploads.values.flatten.uniq.each { |attachment| attachments << attachment }
    end

    def compose_issue_template_description
      return unless issue_template_active? && issue_template.form?

      self.description = issue_template_composer.compose
    end

    def validate_issue_template_answers
      return unless issue_template_active? && issue_template.form?

      issue_template_composer.problems.each do |element, problem|
        message = case problem
                  when :too_short then ::I18n.t('activerecord.errors.messages.too_short', count: element.min_length)
                  when :unchecked then ::I18n.t(:issue_template_error_unchecked)
                  else ::I18n.t('activerecord.errors.messages.blank')
                  end
        errors.add(:base, "#{element.label}#{::I18n.t(:issue_template_error_separator)}#{message}")
      end
    end
  end
end
