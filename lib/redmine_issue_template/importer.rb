# frozen_string_literal: true

module RedmineIssueTemplate
  # Stores a project's template files and where they came from. The entry
  # point for other plugins too: redmine_github calls #import with the files
  # of a push (docs/sync.md#redmine-github).
  module Importer
    module_function

    # Replaces the project's files with the given ones.
    #   files:    { "bug.yml" => "...", ... } (file names in the folder)
    #   revision: the commit they come from (shown in the settings)
    #   source:   "repository", "github" or "manual"
    #   folder:   the folder they were read from, e.g. ".github/ISSUE_TEMPLATE"
    # Returns the IssueTemplateSource; IssueTemplateSource.messages_for gives
    # the errors and warnings.
    def import(project, files:, revision: nil, source: 'repository', folder: nil)
      raise ArgumentError, "unknown source: #{source}" unless SOURCES.include?(source)

      files = files.to_h { |path, content| [File.basename(path.to_s), utf8(content)] }
                   .select { |path, _| storable?(project, path) }
      record = IssueTemplateFile.transaction do
        # One import at a time per project (a fetch, the button and a push
        # can come together).
        project.lock!
        store(project, files)
        IssueTemplateSource.for(project).tap do |source_record|
          source_record.update!(kind: source, folder: folder, revision: revision, digest: digest(files),
                                synced_at: Time.current)
        end
      end
      TemplateSet.reset!
      record
    end

    # The project's files replaced by these. A file too long to store is kept
    # empty, marked as too long.
    def store(project, files)
      IssueTemplateFile.where(project_id: project.id).delete_all
      files.each do |path, content|
        too_long = content.length > Parser::MAX_LENGTH
        IssueTemplateFile.create!(project: project, path: path, content: too_long ? '' : content, too_long: too_long)
      end
    end

    # Text in UTF-8, as Redmine reads the repository's files.
    def utf8(content)
      Redmine::CodesetUtil.to_utf8_by_setting(content.to_s)
    end

    # A template file with a name the project can store; others are left
    # out, so that one odd name doesn't stop the import.
    def storable?(project, path)
      return false unless Parser.kind(path)
      return true if path.length <= 255 && IssueTemplateFile::PATH.match?(path)

      Rails.logger.warn("redmine_issue_template: #{project.identifier}: file name not used: #{path.inspect}")
      false
    end

    # The same for the repository's raw files and the stored ones.
    def digest(files)
      Digest::SHA256.hexdigest(files.to_h { |path, content| [path, utf8(content)] }.sort.to_s)
    end
  end
end
