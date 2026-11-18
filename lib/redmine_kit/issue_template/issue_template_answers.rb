# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # A form's answers and uploaded files on a new issue: the description made
    # from them, their checks, and the files attached. Part of IssuePatch.
    module IssueTemplateAnswers
      # The files of a form's upload fields: { ref => [Attachment] }, given by
      # the controller (IssueTemplateParams#issue_template_uploads_param), and
      # those the new UI names by id (#issue_template_upload_ids).
      def issue_template_uploads
        (@issue_template_uploads || {}).merge(issue_template_named_uploads) { |_ref, given, named| given + named }
      end

      # The new UI's upload fields: { ref => [attachment id] }. Each id is
      # looked up among the files Redmine's create took from its own `uploads`
      # (save_attachments, before the issue is validated: Attachment.find_by_token
      # gives only files not attached yet) and that the user uploaded, so an id
      # can't bring in a file of another user or one the request didn't give.
      def issue_template_upload_ids
        @issue_template_upload_ids || {}
      end

      def issue_template_composer
        BodyComposer.new(issue_template, issue_template_answers,
                         files: issue_template_uploads.transform_values { |list| list.map(&:filename) },
                         linked: issue_template_links.map(&:element), dropped: issue_template_dropped)
      end

      private

      def issue_template_named_uploads
        return {} if issue_template_upload_ids.empty?

        mine = saved_attachments.select { |attachment| attachment.author_id == User.current.id }
        issue_template_upload_ids.transform_values do |ids|
          ids.filter_map { |id| mine.detect { |attachment| attachment.id == id } }.uniq
        end
      end

      # The upload fields' files become the issue's files, as Redmine attaches
      # the files of its own Files field. Those named by id are Redmine's own
      # uploads, which Redmine attaches itself.
      def attach_issue_template_uploads
        (@issue_template_uploads || {}).values.flatten.uniq.each { |attachment| attachments << attachment }
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
                    when :not_accepted then ::I18n.t(:issue_template_error_not_accepted,
                                                     value: element.accept.join(', '))
                    else ::I18n.t('activerecord.errors.messages.blank')
                    end
          errors.add(:base, "#{element.label}#{::I18n.t(:issue_template_error_separator)}#{message}")
        end
      end
    end
  end
end
