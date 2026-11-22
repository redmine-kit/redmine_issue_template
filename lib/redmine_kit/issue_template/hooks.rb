# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    class Hooks < Redmine::Hook::ViewListener
      render_on :view_issues_new_top, partial: 'redmine_kit/issue_template/templates/intro'
      render_on :view_issues_form_details_top, partial: 'redmine_kit/issue_template/templates/form_key'

      # The new UI's counterpart of the two above (redmine_kit_ui's hook, called
      # only where redmine_kit_ui is installed): the chooser as a step of the
      # form, or the template's part of it (KitForm).
      def kit_ui_new_issue_form(context)
        KitForm.answer(context[:issue], context[:params])
      end

      # Redmine's project copy: チケットテンプレート in the copy page's list
      # (with the number of files, as Redmine's items), and the copy itself
      # when it was chosen (ProjectCopy).
      def view_projects_copy_only_items(context = {})
        project = context[:project]
        RedmineKit::Subprojects::ProjectCopy.check_box(context[:hook_caller], ProjectCopy::ITEM,
                                                       l(:label_issue_template_plural),
                                                       TemplateFile.where(project_id: project.id).count)
      end

      def model_project_copy_before_save(context = {})
        destination = context[:destination_project]
        return unless RedmineKit::Subprojects::ProjectCopy.chosen?(destination, ProjectCopy::ITEM)

        ProjectCopy.copy(context[:source_project], destination)
      end
    end
  end
end
