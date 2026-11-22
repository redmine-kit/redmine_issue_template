# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # A project's templates in Redmine's project copy (the copy page's item
    # チケットテンプレート, Hooks): the files, and the source's sharing. The
    # copy's files are edited in its settings (manual), because Redmine's copy
    # takes no repository with it, so nothing could import them there.
    module ProjectCopy
      ITEM = 'issue_templates'

      module_function

      def copy(source, destination)
        files = TemplateFile.where(project_id: source.id).to_a
        from = TemplateSource.find_by(project_id: source.id)
        return if files.empty? && from.nil?

        TemplateFile.transaction do
          files.each do |file|
            TemplateFile.create!(project_id: destination.id, path: file.path, content: file.content,
                                 too_long: file.too_long)
          end
          TemplateSource.create!(project_id: destination.id, kind: 'manual', sharing: from&.sharing || 'none')
        end
      end
    end
  end
end
