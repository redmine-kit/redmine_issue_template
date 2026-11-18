# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    class Hooks < Redmine::Hook::ViewListener
      render_on :view_issues_new_top, partial: 'issue_templates/intro'
      render_on :view_issues_form_details_top, partial: 'issue_templates/form_key'

      # The new UI's counterpart of the two above (redmine_kit_ui's hook, called
      # only where redmine_kit_ui is installed): the chooser as a step of the
      # form, or the template's part of it (KitForm).
      def kit_ui_new_issue_form(context)
        KitForm.answer(context[:issue], context[:params])
      end
    end
  end
end
