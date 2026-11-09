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
    # Returns the IssueTemplateSource with the errors and warnings.
    def import(project, files:, revision: nil, source: 'repository', folder: nil)
      raise ArgumentError, "unknown source: #{source}" unless SOURCES.include?(source)

      files = files.to_h { |path, content| [File.basename(path.to_s), content.to_s] }
                   .select { |path, _| Parser.kind(path) }
      record = IssueTemplateSource.for(project)
      IssueTemplateFile.transaction do
        IssueTemplateFile.where(project_id: project.id).delete_all
        files.each { |path, content| IssueTemplateFile.create!(project: project, path: path, content: content) }
        record.attributes = { kind: source, folder: folder, revision: revision, digest: digest(files),
                              synced_at: Time.current }
        record.message_list = messages(project, files)
        record.save!
      end
      TemplateSet.reset!
      record
    end

    # The errors and warnings of the stored files again, after an edit in
    # the project settings.
    def refresh(project)
      record = IssueTemplateSource.for(project)
      record.kind ||= 'manual'
      files = IssueTemplateFile.where(project_id: project.id).pluck(:path, :content).to_h
      record.message_list = messages(project, files)
      record.digest = digest(files)
      record.save!
      TemplateSet.reset!
      record
    end

    def digest(files)
      Digest::SHA256.hexdigest(files.sort.to_s)
    end

    def messages(project, files)
      set = Parser.parse(files)
      set.messages + set.usable.flat_map { |template| template.project_warnings(project) }
    end
  end
end
