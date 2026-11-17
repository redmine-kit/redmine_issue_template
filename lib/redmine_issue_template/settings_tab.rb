# frozen_string_literal: true

module RedmineIssueTemplate
  # Project settings › Issue templates: what the tab shows, for Redmine's
  # page (issue_templates/_settings) and the new UI's
  # (GET /projects/:id/issue_templates.json), from one place. Where the files
  # come from, whether they are edited here, the files with their errors and
  # warnings, and the chooser's settings (config.yml).
  class SettingsTab
    attr_reader :project

    def initialize(project)
      @project = project
    end

    def source
      return @source if defined?(@source)

      @source = IssueTemplateSource.find_by(project_id: project.id)
    end

    # The files are edited here (none imported from elsewhere).
    def manual?
      source.nil? || source.manual?
    end

    def set
      @set ||= TemplateSet.for(project)
    end

    def messages
      @messages ||= IssueTemplateSource.messages_for(project)
    end

    def files
      @files ||= IssueTemplateFile.where(project_id: project.id).sort_by { |file| Parser.sort_key(file.path) }
    end

    def template_for(file)
      set.templates.detect { |template| template.path == file.path }
    end

    def messages_for(file)
      messages.select { |message| message.path == file.path }
    end

    def errors?
      messages.any?(&:error?)
    end

    # Templates are read as CommonMark: another text formatting is warned of.
    def text_formatting_warning?
      Setting.text_formatting != 'common_mark'
    end

    def to_h
      { manual: manual?, has_repository: project.repository.present?, source: source_data,
        errors: errors?, text_formatting: text_formatting_warning? ? common_mark_name : nil,
        files: files.map { |file| file_row(file) }, config: config_data, chooser: chooser_data }
    end

    # A file with its messages (the file page's).
    def file_data(file)
      { id: file.id, path: file.path, content: file.content.to_s,
        messages: messages_for(file).map { |found| message(found) } }
    end

    private

    def message(message)
      { level: message.error? ? 'error' : 'warning', text: message.text }
    end

    def source_data
      return nil if manual?

      { kind: source.kind, folder: source.folder.presence || FOLDERS.first, revision: source.revision&.first(8),
        synced_at: source.synced_at&.iso8601 }
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

    def common_mark_name
      Redmine::WikiFormatting.formats_for_select.to_h.invert['common_mark']
    end
  end
end
