# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # Project settings › Issue templates: what the tab shows, for Redmine's
    # page (templates/_settings) and the new UI's
    # (GET /projects/:id/issue_templates.json), from one place. Where the files
    # come from, whether they are edited here, the files with their errors and
    # warnings, and the chooser's settings (config.yml).
    class SettingsTab
      include Redmine::I18n

      attr_reader :project

      def initialize(project)
        @project = project
      end

      def source
        return @source if defined?(@source)

        @source = TemplateSource.find_by(project_id: project.id)
      end

      # The files are edited here (none imported from elsewhere).
      def manual?
        source.nil? || source.manual?
      end

      def set
        @set ||= TemplateSet.own(project)
      end

      def messages
        @messages ||= TemplateSource.messages_for(project)
      end

      def files
        @files ||= TemplateFile.where(project_id: project.id).sort_by { |file| Parser.sort_key(file.path) }
      end

      def template_for(file)
        set.templates.detect { |template| template.path == file.path }
      end

      def messages_for(file)
        messages.select { |message| message.path == file.path }
      end

      def errors_for(file)
        messages_for(file).select(&:error?)
      end

      def errors?
        messages.any?(&:error?)
      end

      # Redmine's name of the CommonMark text formatting, which templates use.
      def common_mark_name
        Redmine::WikiFormatting.formats_for_select.to_h.invert['common_mark']
      end

      # Templates are read as CommonMark: another text formatting is warned of.
      def text_formatting_warning?
        Setting.text_formatting != 'common_mark'
      end

      # The project whose templates the project uses, when it is another one
      # (TemplateSource.provider_for: shared with it, as Redmine shares a
      # version); nil when it uses its own.
      def provider
        return @provider if defined?(@provider)

        found = TemplateSource.provider_for(project)
        @provider = found == project ? nil : found
      end

      # 共有: the value now and those the user may choose (Version's rule and
      # Redmine's labels).
      def sharing
        source&.sharing || 'none'
      end

      # The templates the project uses from the provider while it has none of
      # its own (those its new issues offer: TemplateSet.for's usable ones),
      # read-only here, with the tracker each sets in this project. None
      # without a provider.
      def shared_files
        @shared_files ||= provider ? TemplateSet.for(project).usable : []
      end

      def sharings(user = User.current)
        (source || TemplateSource.new(project:)).allowed_sharings(user)
      end

      def sharing_options(user = User.current)
        RedmineKit::Subprojects::Sharing.options(sharings(user))
      end

      def to_h
        { manual: manual?, has_repository: project.repository.present?, source: source_data,
          sharing: sharing, sharings: sharings,
          provider: provider && { name: provider.name, identifier: provider.identifier },
          shared_files: shared_files.map { |template| shared_row(template) },
          errors: errors?, text_formatting: text_formatting_warning? ? common_mark_name : nil,
          files: files.map { |file| file_row(file) }, config: config_data, chooser: chooser_data }
      end

      # A file with its messages (the file page's).
      def file_data(file)
        { id: file.id, path: file.path, content: file.content.to_s,
          messages: messages_for(file).map { |found| message(found) } }
      end

      # Where the files come from: the repository's folder and the revision
      # they were imported from, with Redmine's pages of them (paths built by
      # Redmine's routes), and when, in the user's format; nil when they are
      # edited here. The tab's and the new issue's sidebar (KitForm).
      def source_data
        return nil if manual?

        folder = source.folder.presence || FOLDERS.first
        { kind: source.kind, folder: folder, revision: source.revision&.first(8),
          synced_at: source.synced_at&.iso8601, synced_at_text: source.synced_at && format_time(source.synced_at),
          **repository_paths(folder) }
      end

      private

      def message(message)
        { level: message.error? ? 'error' : 'warning', text: message.text }
      end

      # The repository's folder and revision pages, for a source that is the
      # project's repository.
      def repository_paths(folder)
        repository = project.repository
        return {} unless source.kind == 'repository' && repository

        routes = Rails.application.routes.url_helpers
        base = { controller: 'repositories', id: project, repository_id: repository.identifier_param, only_path: true }
        { folder_path: routes.url_for(base.merge(action: 'show', path: folder)),
          revision_path: source.revision && routes.url_for(base.merge(action: 'revision', rev: source.revision)) }
      end

      def shared_row(template)
        { path: template.path, kind: Parser.kind(template.path).to_s, name: template.name,
          tracker: template.tracker(project)&.name, form: template.form? }
      end

      def file_row(file)
        template = template_for(file)
        found = messages_for(file)
        { id: file.id, path: file.path, kind: Parser.kind(file.path).to_s, name: template&.name,
          tracker: template&.tracker(project)&.name, form: template&.form? || false,
          errors: found.count(&:error?), warnings: found.count { |message| !message.error? } }
      end

      def config_data
        config = set.config
        { path: config.path || 'config.yml', blank_issues_enabled: config.blank_issues_enabled?,
          contact_links: config.contact_links.map { |link| link.to_h.transform_values(&:to_s) } }
      end

      # The chooser the project's templates make now (the preview of
      # config.yml), as the new issue's step draws it.
      def chooser_data
        KitPreview.chooser(set, project)
      end
    end
  end
end
